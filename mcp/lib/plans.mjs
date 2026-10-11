import { randomUUID } from 'node:crypto';

function canonical(value) {
  if (Array.isArray(value)) return value.map(canonical);
  if (value && typeof value === 'object') return Object.fromEntries(Object.keys(value).sort().map(key => [key, canonical(value[key])]));
  return value;
}

export class PlanError extends Error {
  constructor(code, message) { super(message); this.code = code; }
}

export function createPlanStore({ now = Date.now, ttlMs = 300000, maxPlans = 100 } = {}) {
  const plans = new Map();
  function prune() { for (const [id, entry] of plans) if (entry.expiresAt <= now()) plans.delete(id); }
  return {
    add(operation, args, plan) {
      prune();
      while (plans.size >= maxPlans) plans.delete(plans.keys().next().value);
      const planId = randomUUID();
      const expiresAt = now() + ttlMs;
      // The executor signs and deep-freezes this exact plan object. Preserve its
      // identity; the client only receives a JSON serialization of the preview.
      plans.set(planId, { operation, args: JSON.stringify(canonical(args)), plan, expiresAt });
      return { planId, expiresAt: new Date(expiresAt).toISOString() };
    },
    consume(planId, operation, args) {
      const entry = plans.get(planId);
      if (!entry) throw new PlanError('PLAN_NOT_FOUND', '确认计划不存在或已使用，请重新预览。');
      if (entry.expiresAt <= now()) {
        plans.delete(planId);
        throw new PlanError('PLAN_EXPIRED', '确认计划已过期，请重新预览。');
      }
      if (entry.operation !== operation || entry.args !== JSON.stringify(canonical(args))) throw new PlanError('PLAN_MISMATCH', '操作参数与预览不一致，请使用原参数或重新预览。');
      plans.delete(planId);
      return entry.plan;
    },
  };
}
