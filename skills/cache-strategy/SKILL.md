---
name: cache-strategy
version: 1.0.0
description: |
  Implement a permanent cache-first strategy: check cache before hitting the DB,
  write to cache on first read, invalidate only when data changes. No TTL timeouts.
  Modeled on Play Framework's cache model. Use when asked to "add caching",
  "implement cache strategy", "cache DB results", or "reduce DB load".
triggers:
  - add caching
  - implement cache strategy
  - cache DB results
  - reduce DB load
  - cache first
  - permanent cache
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
  - Edit
  - Write
---

# /cache-strategy

Implement a permanent cache-first strategy: read from cache, fall back to DB on miss, write to cache, invalidate only on data mutation. No expiry timers — the cache stays valid until the underlying data changes.

## Philosophy

The goal is **one DB read per data item, ever** (until it changes):

```
READ:   cache hit? → return cached value
        cache miss? → query DB → write to cache → return value

WRITE:  update DB → invalidate (or update) cache entry → done
```

This is the Play Framework model: no TTL, no polling, no background refresh. The cache is always warm and always correct because it is invalidated precisely when the source changes.

**Why permanent over TTL?**
- TTL caches trade stale reads for simplicity — every expiry is a guaranteed DB hit even if nothing changed
- Permanent caches with invalidation give you zero unnecessary DB hits and zero stale reads
- TTL is only appropriate when you can't know when data changes (third-party APIs, etc.)

## Step 1: Detect cache infrastructure

```bash
# Check for Redis
grep -rn "redis\|Redis\|REDIS_URL" --include="*.json" --include="*.env*" --include="*.yml" --include="*.yaml" --include="*.rb" --include="*.py" --include="*.js" --include="*.ts" . 2>/dev/null | grep -v node_modules | head -10

# Check for Memcached
grep -rn "memcached\|Memcached\|MEMCACHE" --include="*.json" --include="*.env*" --include="*.yml" . 2>/dev/null | grep -v node_modules | head -5

# Check for in-process cache (node-cache, lru-cache, etc.)
grep -rn "lru-cache\|node-cache\|memory-cache\|caffeine\|guava.*cache" --include="*.json" --include="*.js" --include="*.ts" --include="*.java" . 2>/dev/null | grep -v node_modules | head -5
```

Report what's available. If no cache layer exists, recommend Redis as the default and offer to add the client library.

## Step 2: Identify cacheable DB reads

Scan for DB query patterns and classify by cacheability:

**High-value cache candidates** (read often, change rarely):
- User profiles, settings, preferences
- Product/item details
- Configuration tables
- Reference data (categories, tags, enums stored in DB)
- Aggregates that are expensive to compute (counts, sums)

**Poor cache candidates** (skip these):
- Real-time data (live inventory counts, chat messages)
- Per-session data
- Data that changes on every write (e.g., counters that increment on every request)

```bash
# Find the most-called query patterns
grep -rn "\.find\b\|\.findById\|\.findOne\|\.where\|SELECT" \
  --include="*.rb" --include="*.py" --include="*.js" --include="*.ts" \
  . 2>/dev/null | grep -v node_modules | grep -v test | grep -v spec | head -30
```

For each candidate, note:
- Cache key pattern (e.g., `user:{id}`, `product:{slug}`)
- Where it's written/updated (to know where to place invalidation)

## Step 3: Implement cache-first reads

For each cacheable read, apply this pattern:

### Redis (Node.js / TypeScript)
```typescript
async function getUser(id: string) {
  const cacheKey = `user:${id}`;
  const cached = await redis.get(cacheKey);
  if (cached) return JSON.parse(cached);

  const user = await db.users.findById(id);
  await redis.set(cacheKey, JSON.stringify(user)); // no TTL — permanent until invalidated
  return user;
}
```

### Redis (Ruby / Rails)
```ruby
def find_user(id)
  Rails.cache.fetch("user:#{id}") do
    User.find(id)  # only called on cache miss
  end
end
```

### Redis (Python)
```python
def get_user(user_id: int):
    cache_key = f"user:{user_id}"
    cached = redis_client.get(cache_key)
    if cached:
        return json.loads(cached)
    user = db.session.get(User, user_id)
    redis_client.set(cache_key, json.dumps(user.to_dict()))  # no expiry
    return user
```

### Play Framework (Scala)
```scala
def getUser(id: Long): Future[User] = {
  cache.getOrElseUpdate(s"user:$id") {
    userRepository.findById(id)
  }
}
```

## Step 4: Implement cache invalidation on writes

For every place that mutates cached data, add invalidation **immediately after** the DB write succeeds:

### Node.js / TypeScript
```typescript
async function updateUser(id: string, data: Partial<User>) {
  const user = await db.users.update(id, data);
  await redis.del(`user:${id}`); // invalidate on change
  return user;
}
```

### Ruby / Rails
```ruby
def update_user(id, attrs)
  user = User.find(id).tap { |u| u.update!(attrs) }
  Rails.cache.delete("user:#{id}")
  user
end
```

**Important:** invalidate on delete too:
```typescript
async function deleteUser(id: string) {
  await db.users.delete(id);
  await redis.del(`user:${id}`);
}
```

For lists/collections, invalidate the collection key when any item in it changes:
```typescript
await redis.del(`user:${id}`);       // the specific item
await redis.del(`users:list`);       // any cached list that included this item
```

## Step 5: Cache key conventions

Use a consistent key naming scheme across the codebase:

```
<entity>:<identifier>          → user:123, product:slug-name
<entity>:list:<filter>         → products:list:category-5
<entity>:<id>:<relation>       → user:123:orders
aggregate:<entity>:<filter>    → aggregate:orders:user-123-total
```

Document the convention in a comment at the top of your cache module:
```typescript
// Cache key conventions:
// user:{id}                — single user record
// users:list               — paginated user list (invalidate on any user change)
// user:{id}:orders         — orders belonging to a user
```

## Step 6: Cache warming (optional)

For critical data that must never have a cold-start miss, add a warm-up step on app boot:

```typescript
async function warmCache() {
  const activeUsers = await db.users.findActiveUsers();
  await Promise.all(
    activeUsers.map(u => redis.set(`user:${u.id}`, JSON.stringify(u)))
  );
}
```

## Step 7: Summary

Report what was implemented:

```
## Cache Strategy Applied

### Cache layer: Redis (permanent, no TTL)

### Reads cached (X total)
- user:{id} — UserService.getUser()
- product:{slug} — ProductService.findBySlug()
- ...

### Invalidation points added (Y total)
- user:{id} — UserService.updateUser(), UserService.deleteUser()
- product:{slug} — ProductService.updateProduct()
- ...

### Estimated DB load reduction
Before: ~X DB queries/min
After:  ~Y DB queries/min (first-read only, then cache)
```

Note: for data that comes from third-party APIs or sources where you can't intercept writes, use a long TTL (hours, not minutes) as a fallback — but flag these separately so they can be revisited if an invalidation webhook becomes available.
