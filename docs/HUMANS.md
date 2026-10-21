Maintain the codebase with these priorities, in order:

1. Readability for future programmers
2. Maintainability for future programmers
3. Elegance in implementation

Before implementing, consider how the design fits the project's architecture. Three design principles are especially important:

- Single Responsibility Principle (SRP): Keep each class focused on one responsibility. Separate behavior that changes for independent reasons.
- Open/Closed Principle (OCP): Prefer extending behavior through established contracts rather than repeatedly modifying shared code for each new variant.
- Dependency Inversion Principle (DIP): Depend on the smallest stable contract needed by the caller. Supply dependencies explicitly through scene references or initialization. Inheriting from an abstract base class alone does not establish dependency inversion.

Supporting Guidelines:

- Keep related operations together and separate independent responsibilities. Prefer composition unless inheritance represents a stable behavioral contract. Follow the existing Manager/AbstractManaged pattern where it fits the responsibility being implemented.
- Choose class and file names that communicate each component's purpose and its relationship to the rest of the module. A programmer should be able to understand the module's broad structure from its filenames.
- Keep routine implementation changes local. When changing a public contract, identify and update the affected callers.
- Minimize duplicated and externally writable state. Give each piece of runtime state a clear owner. Extract related fields into another class when they form a cohesive concept with its own rules for valid state and behavior.
- Minimize coupling. Give each class only the knowledge it needs about other components. Read or modify another component's state through a narrow, explicit API.
- Separate reusable configuration from runtime behavior. Store authored gameplay configuration in typed Resources and `.tres` assets instead of embedding configuration dictionaries in code. Keep mutable runtime state with its owning system. Resources should expose only the operations they need; CRUD methods are not required.
- Give non-obvious numeric values semantic names. Use named constants for fixed values and exported properties or Resources for tunable configuration.
- Prefer descriptive names and small, cohesive functions. Extract a function when it names a meaningful operation or clarifies the caller; do not split straightforward code into functions solely to avoid comments.
- Use comments to explain non-obvious decisions, invariants, coordinate conventions, or performance constraints. Avoid comments that restate the code, and update comments when the relevant behavior changes.

Code Style Guidelines:

- Use `snake_case` for variables, functions, fields, and signals.
- Use `PascalCase` for class names and script filenames, such as `AbstractEnemy.gd`.
- Use `SCREAMING_SNAKE_CASE` for constants and enum members.
- Prefix private implementation details with an underscore, such as `_pending` or `_begin_next_level`.
- Lifecycle hooks and fields reserved for a manager or subclass contract may also use a leading underscore. Access them only as part of that contract; unrelated callers should use the public API.
- Do not use `camelCase`.

Integration Guidelines:

- Every feature should be its own branch
- Keep your file-touching scope reasonable. be mindful of what others are working on in tandem
- If a PR is merged to main while you are working, or have an outstanding branch, merge it back into your branch and resolve the conflicts
- Feel free to keep your PR concise, listing only major features. screenshots + videos are a big bonus and speak more than words

Integration Tools:

- On PR made, Github workflows will verify whether you've adhered to style guidelines, and whether your code compiles in Godot. If either of these fail, the PR will be auto-rejected.