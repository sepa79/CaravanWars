export type GovernorController = "human" | "deterministic_policy" | "ai";

export interface ManagedEntityGovernance {
  readonly entityId: string;
  readonly ownerId: string;
  readonly governorActorId: string | null;
}

export interface GovernorDefinition {
  readonly actorId: string;
  readonly principalId: string;
  readonly superiorActorId: string | null;
  readonly roles: readonly string[];
  readonly authorityScopes: readonly string[];
  readonly controller: GovernorController;
}

export interface AuthorityDelegation {
  readonly delegationId: string;
  readonly delegatorActorId: string;
  readonly delegateActorId: string;
  readonly authorityScopes: readonly string[];
  readonly validFromElapsedDays: number;
  readonly validUntilElapsedDays: number | null;
}

export interface AuthorityQuery {
  readonly issuerActorId: string;
  readonly managedEntityId: string;
  readonly requiredScope: string;
  readonly elapsedDays: number;
}

export interface AuthorityDecision {
  readonly authorized: boolean;
  readonly basis: "direct_governor" | "superior" | "delegation" | "none";
  readonly authorityActorId: string | null;
}

export interface GovernanceSnapshot {
  readonly managedEntities: readonly ManagedEntityGovernance[];
  readonly governors: readonly GovernorDefinition[];
  readonly delegations: readonly AuthorityDelegation[];
}

export class GovernanceValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "GovernanceValidationError";
  }
}

export class Governance {
  readonly #entities: ReadonlyMap<string, ManagedEntityGovernance>;
  readonly #governors: ReadonlyMap<string, GovernorDefinition>;
  readonly #delegations: readonly AuthorityDelegation[];

  constructor(snapshot: GovernanceSnapshot) {
    this.#entities = indexUnique(
      snapshot.managedEntities.map((item) => ({ ...item })),
      (item) => item.entityId,
      "managed entity",
    );
    this.#governors = indexUnique(
      snapshot.governors.map(copyGovernor),
      (item) => item.actorId,
      "governor",
    );
    this.#delegations = snapshot.delegations.map(copyDelegation);
    this.#validate();
  }

  authorize(query: AuthorityQuery): AuthorityDecision {
    if (!Number.isFinite(query.elapsedDays) || query.elapsedDays < 0) {
      throw new GovernanceValidationError("Authority query time must be finite and non-negative.");
    }
    const entity = this.#entities.get(query.managedEntityId);
    if (entity === undefined || entity.governorActorId === null) return denied();

    let actorId: string | null = entity.governorActorId;
    let basis: AuthorityDecision["basis"] = "direct_governor";
    while (actorId !== null) {
      const governor = this.#governors.get(actorId);
      if (governor === undefined) break;
      if (actorId === query.issuerActorId && governor.authorityScopes.includes(query.requiredScope)) {
        return { authorized: true, basis, authorityActorId: actorId };
      }
      const delegation = this.#delegations.find((item) =>
        item.delegatorActorId === actorId
        && item.delegateActorId === query.issuerActorId
        && item.authorityScopes.includes(query.requiredScope)
        && item.validFromElapsedDays <= query.elapsedDays
        && (item.validUntilElapsedDays === null
          || query.elapsedDays < item.validUntilElapsedDays));
      if (delegation !== undefined && governor.authorityScopes.includes(query.requiredScope)) {
        return { authorized: true, basis: "delegation", authorityActorId: actorId };
      }
      actorId = governor.superiorActorId;
      basis = "superior";
    }
    return denied();
  }

  snapshot(): GovernanceSnapshot {
    return {
      managedEntities: [...this.#entities.values()].map((item) => ({ ...item })),
      governors: [...this.#governors.values()].map(copyGovernor),
      delegations: this.#delegations.map(copyDelegation),
    };
  }

  #validate(): void {
    for (const entity of this.#entities.values()) {
      requireId(entity.entityId, "Managed entity id");
      requireId(entity.ownerId, `Managed entity ${entity.entityId} owner id`);
      if (entity.governorActorId !== null && !this.#governors.has(entity.governorActorId)) {
        throw new GovernanceValidationError(
          `Managed entity ${entity.entityId} references missing governor ${entity.governorActorId}.`,
        );
      }
    }
    for (const governor of this.#governors.values()) {
      requireId(governor.actorId, "Governor actor id");
      requireId(governor.principalId, `Governor ${governor.actorId} principal id`);
      requireUniqueIds(governor.roles, `Governor ${governor.actorId} roles`);
      requireUniqueIds(governor.authorityScopes, `Governor ${governor.actorId} scopes`);
      if (governor.superiorActorId !== null && !this.#governors.has(governor.superiorActorId)) {
        throw new GovernanceValidationError(
          `Governor ${governor.actorId} references missing superior ${governor.superiorActorId}.`,
        );
      }
      const visited = new Set<string>();
      let actorId: string | null = governor.actorId;
      while (actorId !== null) {
        if (visited.has(actorId)) {
          throw new GovernanceValidationError(`Governance superior cycle includes ${actorId}.`);
        }
        visited.add(actorId);
        actorId = this.#governors.get(actorId)?.superiorActorId ?? null;
      }
    }
    const delegationIds = new Set<string>();
    for (const delegation of this.#delegations) {
      requireId(delegation.delegationId, "Delegation id");
      if (delegationIds.has(delegation.delegationId)) {
        throw new GovernanceValidationError(`Duplicate delegation id ${delegation.delegationId}.`);
      }
      delegationIds.add(delegation.delegationId);
      if (!this.#governors.has(delegation.delegatorActorId)) {
        throw new GovernanceValidationError(
          `Delegation ${delegation.delegationId} has missing delegator.`,
        );
      }
      requireId(delegation.delegateActorId, `Delegation ${delegation.delegationId} delegate`);
      requireUniqueIds(delegation.authorityScopes, `Delegation ${delegation.delegationId} scopes`);
      if (!Number.isFinite(delegation.validFromElapsedDays)
        || delegation.validFromElapsedDays < 0
        || (delegation.validUntilElapsedDays !== null
          && (!Number.isFinite(delegation.validUntilElapsedDays)
            || delegation.validUntilElapsedDays <= delegation.validFromElapsedDays))) {
        throw new GovernanceValidationError(
          `Delegation ${delegation.delegationId} has an invalid validity interval.`,
        );
      }
    }
  }
}

function denied(): AuthorityDecision {
  return { authorized: false, basis: "none", authorityActorId: null };
}

function indexUnique<T>(
  items: readonly T[],
  idOf: (item: T) => string,
  label: string,
): ReadonlyMap<string, T> {
  const result = new Map<string, T>();
  for (const item of items) {
    const id = idOf(item);
    if (result.has(id)) throw new GovernanceValidationError(`Duplicate ${label} id ${id}.`);
    result.set(id, item);
  }
  return result;
}

function requireUniqueIds(values: readonly string[], label: string): void {
  if (new Set(values).size !== values.length) {
    throw new GovernanceValidationError(`${label} must not contain duplicates.`);
  }
  for (const value of values) requireId(value, label);
}

function requireId(value: string, label: string): void {
  if (value.length === 0) throw new GovernanceValidationError(`${label} must not be empty.`);
}

function copyGovernor(governor: GovernorDefinition): GovernorDefinition {
  return {
    ...governor,
    roles: [...governor.roles],
    authorityScopes: [...governor.authorityScopes],
  };
}

function copyDelegation(delegation: AuthorityDelegation): AuthorityDelegation {
  return { ...delegation, authorityScopes: [...delegation.authorityScopes] };
}
