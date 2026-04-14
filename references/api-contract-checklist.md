# API & Contract Changes Checklist

## Breaking Change Detection

### REST API
- Removed or renamed endpoints
- Removed or renamed query parameters / request body fields
- Changed HTTP method for existing endpoint
- Changed response structure (removed fields, changed types, changed nesting)
- Changed error response format or status codes
- Tightened validation (previously accepted input now rejected)

### GraphQL
- Removed fields from types
- Changed field types (even nullable → non-nullable)
- Removed enum values
- Changed argument types or added required arguments

### Function/Module Exports
- Removed or renamed exported functions/classes/types
- Changed function signature (parameter order, types, return type)
- Changed default parameter values
- Removed re-exports from barrel files

### Database Schema
- Column removal or rename
- Type change on existing column
- Adding NOT NULL without default value
- Removing or changing indexes that external queries depend on

### Questions to Ask
- "Can the previous version's client still call this without changes?"
- "Will existing persisted data be valid under the new schema?"

---

## Backward Compatibility

### Additive-Only Changes (Safe)
- New optional fields in request/response
- New endpoints
- New enum values (if consumer handles unknown values)
- New optional query parameters with defaults

### Migration Strategies for Breaking Changes
1. **Versioning**: New endpoint version (`/v2/users`)
2. **Deprecation period**: Mark old field deprecated, add new, remove later
3. **Alias**: Accept both old and new field names during transition
4. **Feature flag**: Gate new behavior behind a flag for gradual rollout

### Checklist
- [ ] No fields removed from response without deprecation period
- [ ] No required fields added to request without default
- [ ] New validation doesn't reject previously valid input
- [ ] Error codes are stable (consumers may switch on them)
- [ ] Pagination behavior unchanged (offset/cursor compatibility)

---

## Type Safety & Schema

### TypeScript/JS
- Exported type changes match runtime behavior
- Generic constraints not accidentally narrowed
- Union types not accidentally widened (breaks exhaustive checks)
- `as` casts hiding real type mismatches

### Proto/gRPC
- Field numbers not reused (even after deletion — use `reserved`)
- `optional` → `required` is breaking
- Enum value 0 should be UNSPECIFIED/UNKNOWN

### JSON Schema / OpenAPI
- Schema file updated to match implementation
- Example values still valid
- Nullable fields properly annotated

---

## Documentation & Communication

- [ ] CHANGELOG or migration guide updated for breaking changes
- [ ] API docs (OpenAPI/Swagger, GraphQL schema) regenerated
- [ ] TypeScript type definitions published (if public package)
- [ ] Dependent teams/services notified of breaking changes
- [ ] Deprecation timeline communicated

---

## Versioning

### Semantic Versioning Check
- **MAJOR**: Breaking change → bump major version
- **MINOR**: New feature, backward compatible → bump minor version
- **PATCH**: Bug fix, backward compatible → bump patch version

### Questions to Ask
- "Does this change require a major version bump?"
- "Are downstream consumers aware of this change?"
- "Is there a migration path for existing users?"
