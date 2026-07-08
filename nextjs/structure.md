# Next.js code structure

- Use a `src/` directory, which will contain `app/`, `components/`, `dal/`, and `lib/`.
- All files, no matter if they are routing files (Next.js enforced names anyway), components, or utility functions, will use `kebab-case` naming.
- When creating new files with new components, by default, colocate them in the `app/` directory, placing them alongside their corresponding route files.
- If there are lots of component files, consider creating a `_components/` directory on the route level.
- Components that are shared across multiple routes must be placed further upstream, or outsourced to the top-level `components/` directory all together.
