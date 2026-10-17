# Absum: Firestore Schema and Security Rules

Status: design, not yet deployed
Backend: Firebase (Auth, Firestore, Cloud Messaging; Cloud Functions once on Blaze)
Related files: `firestore.rules`, `firestore.indexes.json`, `test/rules.test.mjs`

---

## 1. Principles

- **An account is just a person.** Roles exist only in `memberships`, per club or per team.
- **Permissions, not role names.** Rules check `can('event.create', …)`. The mapping from roles to permissions lives in one place (`rolePerms()` in the rules), so custom roles later only change that function.
- **Nothing that counts as history is deleted.** Leaving a team sets a status. Account deletion anonymizes names but keeps responses and attendance.
- **Visibility decides document boundaries.** Firestore rules can't hide single fields, so data with different readers goes into different documents (responses vs. reasons vs. attendance).
- **Denormalized `clubId`, always verified.** `clubId` is copied onto teams, memberships, invites and events so rules can check club admins cheaply. Wherever a client supplies it, rules compare it with the team document. Without that check, an admin of another club could claim rights in your team.
- **Rules are not filters.** A query is rejected unless every document it could return is readable, so the app's queries must include the fields the rules check (see section 6).

## 2. Collections

```
users/{uid}                          private profile
  devices/{deviceId}                 push tokens
clubs/{clubId}
teams/{teamId}
  memberPrivate/{uid}                optional export data (NDS)
memberships/{t_teamId_uid | c_clubId_uid}
invites/{code}
eventSeries/{seriesId}               template for recurring events
events/{eventId}
  responses/{uid}                    Ja / Nein / Unsicher
  reasons/{uid}                      free-text reason
  attendance/{uid}                   actual attendance
```

All times are Firestore `Timestamp`s. Each team stores its time zone (`Europe/Zurich`) for display and recurrence.

### users/{uid}
Readable and writable by the owner only.

| Field | Type | Notes |
|---|---|---|
| displayName | string ≤ 60 | Copied into memberships |
| photoURL | string? | |
| locale | `de-CH` \| `en` | |
| notificationPrefs | map | Per type / per team switches |
| createdAt, updatedAt | timestamp | `updatedAt` = server time |

**devices/{deviceId}:** `fcmToken`, `platform` (`ios`), `locale`, `updatedAt`.

### clubs/{clubId}
| Field | Type | Notes |
|---|---|---|
| name | string ≤ 80 | |
| createdBy | uid | |
| createdAt | timestamp | |

A club is created in **one batch** with the creator's admin membership `c_{clubId}_{uid}`. The rules allow each document only if the other is in the same batch.

### teams/{teamId}
| Field | Type | Notes |
|---|---|---|
| clubId | string | Immutable |
| name | string ≤ 80 | |
| sport | string? | Optional label, defaults only |
| timezone | string | e.g. `Europe/Zurich` |
| archived | bool | Teams are archived, not deleted |
| settings.reasonVisibility | `staff` \| `team` | Default `staff` |
| settings.defaultReminderOffsetMin | int | Pre-fills new events, e.g. 1440 |
| settings.defaultLockOffsetMin | int? | null = never lock |
| createdAt | timestamp | |

**memberPrivate/{uid}:** `ndsPersonId`, `fields` (map, your NDS fields), `updatedAt`, `updatedBy`. Readable by the person and team staff, writable by the person and coaches.

### memberships/{id}
ID: `t_{teamId}_{uid}` for team roles, `c_{clubId}_{uid}` for club roles. The deterministic ID is what lets a rule look up "is this person a coach here" with one read.

| Field | Type | Notes |
|---|---|---|
| uid | string | |
| scope | `team` \| `club` | |
| clubId | string | Always set |
| teamId | string \| null | null for club scope |
| roleId | `coach` \| `assistantCoach` \| `player` (team), `admin` (club) | |
| status | `active` \| `pending` \| `left` \| `removed` | |
| displayName, photoURL | | Copy of the profile, readable by teammates |
| accountDeleted | bool? | Set on anonymization |
| inviteCode | string? | Code used to join |
| joinedAt, leftAt | timestamp | |
| updatedAt, updatedBy | | |

Club admins have every team permission in all teams of their club, so a club needs no player-level club memberships.

### invites/{code}
The document ID is the code: 8–16 random characters from an unambiguous alphabet, e.g. `K7M2QX9P`. Anyone signed in can **get** an invite by code, but nobody can list them except team staff.

| Field | Type | Notes |
|---|---|---|
| teamId, clubId | string | Verified against the team |
| requiresApproval | bool | true → joiner is `pending` |
| revoked | bool | |
| expiresAt | timestamp | Max. 90 days ahead |
| createdBy, createdAt | | |

### eventSeries/{seriesId}
`teamId`, `clubId`, `template` (map: type, title, start time, duration, meet offset, location, notes, reminder and lock offsets), `recurrence` (map: `freq: weekly`, `weekdays`, `until`), `createdBy`.

### events/{eventId}
| Field | Type | Notes |
|---|---|---|
| teamId, clubId | string | Immutable |
| type | `training` \| `game` \| `tournament` \| `other` | |
| title | string ≤ 80 | |
| startAt, endAt | timestamp | endAt > startAt |
| meetAt | timestamp? | ≤ startAt |
| location | map? | `{ name, address }` |
| notes | string? ≤ 1000 | |
| status | `scheduled` \| `cancelled` | |
| reminderAt | timestamp? | < startAt |
| lockAt | timestamp? | null = never lock; ≤ endAt |
| remindedAt | timestamp? | Set by the reminder function only |
| seriesId | string? | |
| isException | bool? | Instance edited separately from its series |
| createdBy, createdAt, updatedAt, updatedBy | | |

### events/{eventId}/responses/{uid}
| Field | Type | Notes |
|---|---|---|
| uid, teamId, clubId, eventStartAt | | Copied from the event, verified by rules, used for statistics queries |
| status | `yes` \| `no` \| `unsure` | No document = no answer yet |
| setByStaff | bool | true when a coach answered on behalf |
| clientTime | timestamp | When the user tapped, set by the device |
| updatedAt, updatedBy | | Server time |

### events/{eventId}/reasons/{uid}
`uid`, `teamId`, `clubId`, `eventStartAt`, `text` (≤ 200), `updatedAt`, `updatedBy`.

### events/{eventId}/attendance/{uid}
`uid`, `teamId`, `clubId`, `eventStartAt`, `present` (bool), `recordedBy`, `recordedAt`.
`eventStartAt` makes the export a single collection-group query per period.

## 3. Permission matrix

| Permission | Club admin | Coach | Assistant coach | Player |
|---|:-:|:-:|:-:|:-:|
| event.create / event.edit | ✓ | ✓ | ✓ | |
| response.editOthers (also after the lock) | ✓ | ✓ | ✓ | |
| attendance.edit | ✓ | ✓ | ✓ | |
| reasons.read | ✓ | ✓ | ✓ | only if team setting = `team` |
| memberPrivate.read | ✓ | ✓ | ✓ | own |
| invites.manage | ✓ | ✓ | ✓ | |
| members.manage (approve, remove, change roles) | ✓ | ✓ | | |
| team.settings | ✓ | ✓ | | |
| create teams, manage club admins | ✓ | | | |

Making assistant-coach rights toggleable per club is left for custom roles. In v1 the matrix is fixed.

## 4. Who can read and write what

| Collection | Read | Create / update | Delete |
|---|---|---|---|
| users, devices | Owner | Owner | Owner |
| clubs | Any signed-in user, by ID (no listing) | Create: anyone, with own admin membership in the same batch. Update name: admin | No (Cloud Function) |
| teams | Any signed-in user, by ID. List: club admin | Create: club admin. Update: `team.settings`; clubId immutable | No, archive instead |
| memberPrivate | Owner, `memberPrivate.read` | Owner, `members.manage` | `members.manage` |
| memberships | Own; active members of the team; club admins | See section 5 | No |
| invites | Get by code: signed-in. List: `invites.manage` | `invites.manage`, verified team/club | `invites.manage` |
| eventSeries, events | Active team members, club admins | `event.create` / `event.edit`, verified team/club, clients can't set `remindedAt` | `event.edit` |
| responses | Team members, club admins | Own answer while open; `response.editOthers` anytime | Own (while open, not coach-set); staff |
| reasons | Author, `reasons.read`, team members if visibility = `team` | Author while open; staff | Author; staff |
| attendance | The person; `attendance.edit` | `attendance.edit` | `attendance.edit` |

## 5. Membership rules in detail

**Create, one of:**
1. **Club bootstrap:** your own `admin` membership for a club created in the same batch.
2. **Invite join:** your own `player` membership with a valid, unrevoked, unexpired code for that team. Status must be `pending` if the invite requires approval, otherwise `active`. Nobody can choose another role.
3. **Added by a manager:** `members.manage` in the team (club admins for club memberships), with the team verified to belong to the club.

**Update, one of:**
1. **Profile sync:** you change only your own `displayName`, `photoURL` or `accountDeleted`.
2. **Leave:** from `active` or `pending` to `left`. **Admins can't leave on their own.** Another admin must demote them first. That guarantees a club never ends up without an admin, without needing a Cloud Function.
3. **Rejoin:** from `left` back via a valid invite. `removed` members can only be re-added by a manager.
4. **Manage:** someone with `members.manage` approves, removes or changes roles of others. Nobody changes their own role.

## 6. Queries the app must use

Because rules are not filters, these shapes matter:

| Screen | Query |
|---|---|
| My teams | `memberships where uid == me and status == active` |
| Team members | `memberships where teamId == T` (club admins who aren't members also add `clubId == C`) |
| Home / upcoming | **one listener per team:** `events where teamId == T and startAt >= now orderBy startAt`. Don't use `teamId in [...]`: the read rule needs each team checked separately. |
| Event responses | `events/E/responses` (whole subcollection) |
| Reasons, coach view | `events/E/reasons`, only if staff or visibility = `team`. Otherwise get your own `events/E/reasons/{me}`. Listing would fail. |
| Export | `collectionGroup('attendance') where teamId == T and clubId == C and eventStartAt in [from, to)` |
| Own reasons (deletion) | `collectionGroup('reasons') where uid == me` |

Indexes for these are in `firestore.indexes.json`.

## 7. Behaviour encoded in the rules

- **Response lock:** players can answer only while the event is `scheduled` and before `lockAt`. Staff ignore the lock.
- **Coach override vs. offline answers:** a player can overwrite a coach-set answer only if their `clientTime` is later than the coach's change. A queued offline answer from before the override is rejected, and the app must show it as "not saved". `clientTime` may be at most 2 minutes in the future, so it can't be faked to always win.
- **Answers only from members:** staff can answer for, and record attendance of, active team members only.
- **Copied event fields must match:** `teamId`, `clubId` and `eventStartAt` on responses, reasons and attendance must equal the event. If an event is moved, the app rewrites them on the next write. The export reads `eventStartAt` from attendance, so attendance recorded before a move keeps the old date.

## 8. Spark (free) vs. Blaze

**Works on Spark, rules only:**
- Sign-up, clubs, teams, invites and joining, approval, roles
- Events, recurring events: the coach's device creates all instances up to `until` in one batch (max. 500 writes)
- Responses, reasons, attendance, CSV export on the device
- Account deletion, done by the client in this order:
  1. Anonymize own memberships (`Ehemaliges Mitglied`, photo removed, `accountDeleted: true`)
  2. Delete own reasons (collection-group query)
  3. Delete devices and the user document
  4. Delete the Auth account (may require recent sign-in)
- Reminders as **local notifications**, scheduled on the device per event and cancelled when answered. iOS allows 64 pending notifications.

**Needs Blaze (Cloud Functions):**
- Server reminders: a scheduled function every 5 minutes finds `status == scheduled, remindedAt == null, reminderAt <= now`, notifies members without a response, then sets `remindedAt`. Editing `reminderAt` resets `remindedAt` to null.
- Alerts for new, changed and cancelled events (Firestore trigger on `events`)
- "Offene erinnern" nudge (callable, with a rate limit)
- Deleting a whole club (cascade)
- Moving account deletion server-side, for robustness

Pushes carry a localization key (`loc-key`), so the device shows German or English from its own string catalog.

## 9. Costs to watch

- Each `get()` or `exists()` in a rule is billed as a read, once per document per request. The most expensive path is a staff answer on behalf (event + own team membership + own club membership + target membership = 4 reads). Listeners re-evaluate rules when results change.
- One listener per team on the Home screen is a deliberate trade-off. It's a few extra listeners, but no denormalized member lists on every event.

## 10. Testing

`test/rules.test.mjs` covers 27 allow/deny cases: club bootstrap, invite join and its abuse cases, the cross-club `clubId` trick, the last-admin rule, the lock, coach override vs. offline answers, reason visibility, and the attendance export.

```
npm install
npm test        # starts the Firestore emulator and runs the tests
```

The emulator needs Java 21 or newer.

## 11. Open points

- Widgets: shared Firebase auth in a keychain access group, or answers queued in an App Group for the app to sync
- Which fields `memberPrivate.fields` needs for the NDS CSV
- Check that a Swiss database location exists before creating the database (it can't be changed later)
- Statistics (responses vs. attendance) would need a `responses` collection-group index on `teamId` + `eventStartAt`
