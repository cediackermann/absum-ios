import { readFileSync } from 'node:fs';
import { describe, it, beforeAll, afterAll, beforeEach } from 'vitest';
import {
  initializeTestEnvironment, assertSucceeds, assertFails,
} from '@firebase/rules-unit-testing';
import {
  doc, getDoc, setDoc, updateDoc, deleteDoc, writeBatch, collection, query, where, getDocs,
  serverTimestamp, Timestamp, collectionGroup,
} from 'firebase/firestore';

let env;
const H = 3600 * 1000;
const ts = (ms) => Timestamp.fromMillis(ms);
const now = Date.now();

// Fixture: club C1 with team T1. admin=club admin, coach, asst, p1, p2 players, outsider.
// Club C2 with team T2, admin2 is its admin.
async function seed() {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const m = (id, data) => setDoc(doc(db, 'memberships', id), {
      displayName: data.uid, updatedAt: ts(now), updatedBy: data.uid, joinedAt: ts(now), ...data,
    });
    await setDoc(doc(db, 'clubs/C1'), { name: 'VBC Beispiel', createdBy: 'admin', createdAt: ts(now) });
    await setDoc(doc(db, 'clubs/C2'), { name: 'Other', createdBy: 'admin2', createdAt: ts(now) });
    const team = (clubId, vis = 'staff') => ({
      clubId, name: 'U20', timezone: 'Europe/Zurich', archived: false, createdAt: ts(now),
      settings: { reasonVisibility: vis, defaultReminderOffsetMin: 1440, defaultLockOffsetMin: 120 },
    });
    await setDoc(doc(db, 'teams/T1'), team('C1'));
    await setDoc(doc(db, 'teams/T2'), team('C2'));
    await m('c_C1_admin', { uid: 'admin', scope: 'club', clubId: 'C1', teamId: null, roleId: 'admin', status: 'active' });
    await m('c_C2_admin2', { uid: 'admin2', scope: 'club', clubId: 'C2', teamId: null, roleId: 'admin', status: 'active' });
    for (const [uid, roleId] of [['coach', 'coach'], ['asst', 'assistantCoach'], ['p1', 'player'], ['p2', 'player']]) {
      await m(`t_T1_${uid}`, { uid, scope: 'team', clubId: 'C1', teamId: 'T1', roleId, status: 'active' });
    }
    await m('t_T1_gone', { uid: 'gone', scope: 'team', clubId: 'C1', teamId: 'T1', roleId: 'player', status: 'left' });
    await setDoc(doc(db, 'invites/ABCD2345'), {
      teamId: 'T1', clubId: 'C1', requiresApproval: true, revoked: false,
      expiresAt: ts(now + 24 * H), createdBy: 'coach', createdAt: ts(now),
    });
    await setDoc(doc(db, 'invites/OPEN2345'), {
      teamId: 'T1', clubId: 'C1', requiresApproval: false, revoked: false,
      expiresAt: ts(now + 24 * H), createdBy: 'coach', createdAt: ts(now),
    });
    await setDoc(doc(db, 'invites/OLD02345'), {
      teamId: 'T1', clubId: 'C1', requiresApproval: false, revoked: false,
      expiresAt: ts(now - H), createdBy: 'coach', createdAt: ts(now - 48 * H),
    });
    const event = (extra = {}) => ({
      teamId: 'T1', clubId: 'C1', type: 'training', title: 'Training U20',
      startAt: ts(now + 48 * H), endAt: ts(now + 50 * H), status: 'scheduled',
      reminderAt: ts(now + 24 * H), lockAt: ts(now + 46 * H), remindedAt: null,
      createdBy: 'coach', createdAt: ts(now), updatedAt: ts(now), updatedBy: 'coach', ...extra,
    });
    await setDoc(doc(db, 'events/E1'), event());
    await setDoc(doc(db, 'events/LOCKED'), event({ lockAt: ts(now - H), startAt: ts(now + H), endAt: ts(now + 3 * H), reminderAt: null }));
    await setDoc(doc(db, 'events/E1/responses/p2'), {
      uid: 'p2', teamId: 'T1', clubId: 'C1', eventStartAt: ts(now + 48 * H), status: 'no',
      setByStaff: true, clientTime: ts(now), updatedAt: ts(now), updatedBy: 'coach',
    });
    await setDoc(doc(db, 'events/E1/reasons/p2'), {
      uid: 'p2', teamId: 'T1', clubId: 'C1', eventStartAt: ts(now + 48 * H), text: 'krank',
      updatedAt: ts(now), updatedBy: 'p2',
    });
  });
}

const as = (uid) => env.authenticatedContext(uid).firestore();
const response = (uid, status, by, extra = {}) => ({
  uid, teamId: 'T1', clubId: 'C1', eventStartAt: ts(now + 48 * H), status,
  setByStaff: uid !== by, clientTime: Timestamp.now(), updatedAt: serverTimestamp(), updatedBy: by, ...extra,
});
const startOf = (eventId) => (eventId === 'LOCKED' ? ts(now + H) : ts(now + 48 * H));

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: 'absum-test',
    firestore: { rules: readFileSync('firestore.rules', 'utf8'), host: '127.0.0.1', port: 8080 },
  });
});
afterAll(async () => { await env.cleanup(); });
beforeEach(async () => { await env.clearFirestore(); await seed(); });

describe('clubs and memberships', () => {
  it('anyone can create a club together with their own admin membership', async () => {
    const db = as('newbie');
    const b = writeBatch(db);
    b.set(doc(db, 'clubs/C9'), { name: 'Neuer Club', createdBy: 'newbie', createdAt: serverTimestamp() });
    b.set(doc(db, 'memberships/c_C9_newbie'), {
      uid: 'newbie', scope: 'club', clubId: 'C9', teamId: null, roleId: 'admin', status: 'active',
      displayName: 'Newbie', joinedAt: serverTimestamp(), updatedAt: serverTimestamp(), updatedBy: 'newbie',
    });
    await assertSucceeds(b.commit());
  });

  it('cannot make yourself admin of an existing club', async () => {
    const db = as('outsider');
    await assertFails(setDoc(doc(db, 'memberships/c_C1_outsider'), {
      uid: 'outsider', scope: 'club', clubId: 'C1', teamId: null, roleId: 'admin', status: 'active',
      displayName: 'X', updatedAt: serverTimestamp(), updatedBy: 'outsider',
    }));
  });

  const join = (uid, code, status, roleId = 'player') => ({
    uid, scope: 'team', clubId: 'C1', teamId: 'T1', roleId, status, displayName: uid,
    inviteCode: code, joinedAt: serverTimestamp(), updatedAt: serverTimestamp(), updatedBy: uid,
  });

  it('joins as pending player with an approval invite', async () => {
    await assertSucceeds(setDoc(doc(as('newbie'), 'memberships/t_T1_newbie'), join('newbie', 'ABCD2345', 'pending')));
  });
  it('cannot skip approval, pick a role, or use an expired invite', async () => {
    await assertFails(setDoc(doc(as('newbie'), 'memberships/t_T1_newbie'), join('newbie', 'ABCD2345', 'active')));
    await assertFails(setDoc(doc(as('newbie'), 'memberships/t_T1_newbie'), join('newbie', 'OPEN2345', 'active', 'coach')));
    await assertFails(setDoc(doc(as('newbie'), 'memberships/t_T1_newbie'), join('newbie', 'OLD02345', 'active')));
  });
  it('joins directly as active player with an open invite', async () => {
    await assertSucceeds(setDoc(doc(as('newbie'), 'memberships/t_T1_newbie'), join('newbie', 'OPEN2345', 'active')));
  });
  it('a member who left can rejoin with an invite', async () => {
    await assertSucceeds(updateDoc(doc(as('gone'), 'memberships/t_T1_gone'), {
      status: 'active', inviteCode: 'OPEN2345', updatedAt: serverTimestamp(), updatedBy: 'gone',
    }));
  });

  it('players read team members, outsiders do not', async () => {
    const q = (db) => query(collection(db, 'memberships'), where('teamId', '==', 'T1'));
    await assertSucceeds(getDocs(q(as('p1'))));
    await assertFails(getDocs(q(as('outsider'))));
  });
  it('a user lists their own memberships', async () => {
    await assertSucceeds(getDocs(query(collection(as('p1'), 'memberships'), where('uid', '==', 'p1'))));
  });

  it('a player can leave; an admin cannot leave alone', async () => {
    await assertSucceeds(updateDoc(doc(as('p1'), 'memberships/t_T1_p1'), {
      status: 'left', leftAt: serverTimestamp(), updatedAt: serverTimestamp(), updatedBy: 'p1',
    }));
    await assertFails(updateDoc(doc(as('admin'), 'memberships/c_C1_admin'), {
      status: 'left', leftAt: serverTimestamp(), updatedAt: serverTimestamp(), updatedBy: 'admin',
    }));
  });
  it('a player cannot promote themself; a coach can promote others', async () => {
    await assertFails(updateDoc(doc(as('p1'), 'memberships/t_T1_p1'), {
      roleId: 'coach', updatedAt: serverTimestamp(), updatedBy: 'p1',
    }));
    await assertSucceeds(updateDoc(doc(as('coach'), 'memberships/t_T1_p1'), {
      roleId: 'assistantCoach', updatedAt: serverTimestamp(), updatedBy: 'coach',
    }));
    await assertFails(updateDoc(doc(as('asst'), 'memberships/t_T1_p2'), {
      roleId: 'coach', updatedAt: serverTimestamp(), updatedBy: 'asst',
    }));
  });
  it('an admin of another club cannot claim a coach role in T1', async () => {
    await assertFails(setDoc(doc(as('admin2'), 'memberships/t_T1_admin2'), {
      uid: 'admin2', scope: 'team', clubId: 'C2', teamId: 'T1', roleId: 'coach', status: 'active',
      displayName: 'A2', updatedAt: serverTimestamp(), updatedBy: 'admin2',
    }));
  });
  it('anonymizing your own membership on account deletion is allowed', async () => {
    await assertSucceeds(updateDoc(doc(as('p1'), 'memberships/t_T1_p1'), {
      displayName: 'Ehemaliges Mitglied', photoURL: null, accountDeleted: true,
      updatedAt: serverTimestamp(), updatedBy: 'p1',
    }));
  });
});

describe('events', () => {
  const newEvent = (by, extra = {}) => ({
    teamId: 'T1', clubId: 'C1', type: 'game', title: 'Heimspiel',
    startAt: ts(now + 72 * H), endAt: ts(now + 75 * H), status: 'scheduled', remindedAt: null,
    reminderAt: ts(now + 48 * H), lockAt: ts(now + 70 * H),
    createdBy: by, createdAt: serverTimestamp(), updatedAt: serverTimestamp(), updatedBy: by, ...extra,
  });
  it('coach, assistant and club admin create events; players cannot', async () => {
    await assertSucceeds(setDoc(doc(as('coach'), 'events/N1'), newEvent('coach')));
    await assertSucceeds(setDoc(doc(as('asst'), 'events/N2'), newEvent('asst')));
    await assertSucceeds(setDoc(doc(as('admin'), 'events/N3'), newEvent('admin')));
    await assertFails(setDoc(doc(as('p1'), 'events/N4'), newEvent('p1')));
  });
  it('admin of another club cannot create events in T1 by faking clubId', async () => {
    await assertFails(setDoc(doc(as('admin2'), 'events/N5'), newEvent('admin2', { clubId: 'C2' })));
  });
  it('members read team events by team query; outsiders cannot', async () => {
    const q = (db) => query(collection(db, 'events'), where('teamId', '==', 'T1'));
    await assertSucceeds(getDocs(q(as('p1'))));
    await assertFails(getDocs(q(as('outsider'))));
  });
  it('clients cannot fake remindedAt', async () => {
    await assertFails(updateDoc(doc(as('coach'), 'events/E1'), {
      remindedAt: Timestamp.now(), updatedAt: serverTimestamp(), updatedBy: 'coach',
    }));
  });
});

describe('responses', () => {
  it('a player answers for themself before the lock', async () => {
    await assertSucceeds(setDoc(doc(as('p1'), 'events/E1/responses/p1'), response('p1', 'yes', 'p1')));
  });
  it('a player cannot answer after the lock, or for someone else', async () => {
    await assertFails(setDoc(doc(as('p1'), 'events/LOCKED/responses/p1'),
      response('p1', 'yes', 'p1', { eventStartAt: startOf('LOCKED') })));
    await assertFails(setDoc(doc(as('p1'), 'events/E1/responses/p2'), response('p2', 'yes', 'p1')));
  });
  it('a coach answers on behalf, also after the lock', async () => {
    await assertSucceeds(setDoc(doc(as('coach'), 'events/LOCKED/responses/p1'),
      response('p1', 'no', 'coach', { eventStartAt: startOf('LOCKED') })));
  });
  it('a queued player answer older than the coach override is rejected', async () => {
    await assertFails(setDoc(doc(as('p2'), 'events/E1/responses/p2'),
      response('p2', 'yes', 'p2', { clientTime: ts(now - H) })));
  });
  it('a player answer made after the coach override wins', async () => {
    await assertSucceeds(setDoc(doc(as('p2'), 'events/E1/responses/p2'), response('p2', 'yes', 'p2')));
  });
  it('teammates see responses; outsiders do not', async () => {
    await assertSucceeds(getDocs(collection(as('p1'), 'events/E1/responses')));
    await assertFails(getDocs(collection(as('outsider'), 'events/E1/responses')));
  });
});

describe('reasons', () => {
  it('coach-only visibility: coach and author read, teammates do not', async () => {
    await assertSucceeds(getDoc(doc(as('coach'), 'events/E1/reasons/p2')));
    await assertSucceeds(getDoc(doc(as('p2'), 'events/E1/reasons/p2')));
    await assertFails(getDoc(doc(as('p1'), 'events/E1/reasons/p2')));
  });
  it('team visibility: teammates read reasons', async () => {
    await env.withSecurityRulesDisabled((ctx) =>
      updateDoc(doc(ctx.firestore(), 'teams/T1'), { 'settings.reasonVisibility': 'team' }));
    await assertSucceeds(getDoc(doc(as('p1'), 'events/E1/reasons/p2')));
  });
  it('a user finds their own reasons for account deletion', async () => {
    await assertSucceeds(getDocs(query(collectionGroup(as('p2'), 'reasons'), where('uid', '==', 'p2'))));
    await assertSucceeds(deleteDoc(doc(as('p2'), 'events/E1/reasons/p2')));
  });
});

describe('attendance', () => {
  const att = (uid, by) => ({
    uid, teamId: 'T1', clubId: 'C1', eventStartAt: ts(now + 48 * H), present: true,
    recordedBy: by, recordedAt: serverTimestamp(),
  });
  it('staff record attendance; players cannot', async () => {
    await assertSucceeds(setDoc(doc(as('asst'), 'events/E1/attendance/p1'), att('p1', 'asst')));
    await assertFails(setDoc(doc(as('p1'), 'events/E1/attendance/p1'), att('p1', 'p1')));
  });
  it('staff export via collection group; players cannot', async () => {
    await env.withSecurityRulesDisabled((ctx) =>
      setDoc(doc(ctx.firestore(), 'events/E1/attendance/p1'), { ...att('p1', 'coach'), recordedAt: ts(now) }));
    const q = (db) => query(collectionGroup(db, 'attendance'),
      where('teamId', '==', 'T1'), where('clubId', '==', 'C1'));
    await assertSucceeds(getDocs(q(as('coach'))));
    await assertFails(getDocs(q(as('p1'))));
  });
});
