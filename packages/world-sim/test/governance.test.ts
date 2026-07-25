import assert from "node:assert/strict";
import test from "node:test";

import { Governance, GovernanceValidationError } from "../src/index.js";
import type { GovernanceSnapshot } from "../src/index.js";

const SNAPSHOT: GovernanceSnapshot = {
  managedEntities: [{ entityId: "granary", ownerId: "city", governorActorId: "quartermaster" }],
  governors: [
    {
      actorId: "quartermaster",
      principalId: "city",
      superiorActorId: "mayor",
      roles: ["quartermaster"],
      authorityScopes: ["facility:operate"],
      controller: "deterministic_policy",
    },
    {
      actorId: "mayor",
      principalId: "city",
      superiorActorId: null,
      roles: ["mayor"],
      authorityScopes: ["facility:operate", "facility:policy"],
      controller: "human",
    },
  ],
  delegations: [{
    delegationId: "engineer-shift",
    delegatorActorId: "mayor",
    delegateActorId: "engineer",
    authorityScopes: ["facility:policy"],
    validFromElapsedDays: 2,
    validUntilElapsedDays: 3,
  }],
};

test("separates owner from direct governor and authorizes scoped superior chains", () => {
  const governance = new Governance(SNAPSHOT);
  assert.deepEqual(governance.authorize({
    issuerActorId: "quartermaster",
    managedEntityId: "granary",
    requiredScope: "facility:operate",
    elapsedDays: 0,
  }), { authorized: true, basis: "direct_governor", authorityActorId: "quartermaster" });
  assert.deepEqual(governance.authorize({
    issuerActorId: "mayor",
    managedEntityId: "granary",
    requiredScope: "facility:policy",
    elapsedDays: 0,
  }), { authorized: true, basis: "superior", authorityActorId: "mayor" });
  assert.equal(governance.snapshot().managedEntities[0]?.ownerId, "city");
});

test("delegations are explicit, scoped, and time bounded", () => {
  const governance = new Governance(SNAPSHOT);
  const query = {
    issuerActorId: "engineer",
    managedEntityId: "granary",
    requiredScope: "facility:policy",
  } as const;
  assert.equal(governance.authorize({ ...query, elapsedDays: 1.99 }).authorized, false);
  assert.deepEqual(governance.authorize({ ...query, elapsedDays: 2.5 }), {
    authorized: true,
    basis: "delegation",
    authorityActorId: "mayor",
  });
  assert.equal(governance.authorize({ ...query, elapsedDays: 3 }).authorized, false);
  assert.equal(governance.authorize({
    ...query,
    requiredScope: "facility:operate",
    elapsedDays: 2.5,
  }).authorized, false);
});

test("roles are configuration only and do not imply authority or knowledge", () => {
  const governance = new Governance({
    ...SNAPSHOT,
    governors: [...SNAPSHOT.governors, {
      actorId: "chief_engineer",
      principalId: "city",
      superiorActorId: null,
      roles: ["chief_engineer"],
      authorityScopes: [],
      controller: "ai",
    }],
  });
  assert.equal(governance.authorize({
    issuerActorId: "chief_engineer",
    managedEntityId: "granary",
    requiredScope: "facility:operate",
    elapsedDays: 0,
  }).authorized, false);
});

test("rejects superior cycles", () => {
  assert.throws(() => new Governance({
    managedEntities: [],
    governors: [
      { ...SNAPSHOT.governors[0]!, superiorActorId: "mayor" },
      { ...SNAPSHOT.governors[1]!, superiorActorId: "quartermaster" },
    ],
    delegations: [],
  }), GovernanceValidationError);
});
