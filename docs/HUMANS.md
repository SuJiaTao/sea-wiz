Maintain the codebase with these priorities, in order:

1. Readability for future programmers
2. Maintainability for future programmers
3. Elegance in implementation

Before implementing, consider how the design fits the project's architecture. Three design principles are especially important:

- SRP: each class should have exactly ONE responsibility. If a second one appears, the class must be split.
- OCP: when adding behavior, do it by extending established systems and contracts (these should exist if the codebase is well designed - see: manager classes) instead of designing completely new behavior.
- DIP: when dealing with multiple behaviors, the caller should do as little as possible. delegate the variation in behavior to callees (see: Manager/AbstractManaged classes). Using inheritance alone is not DIP.

Supporting Guidelines:

- you should not write code that is handling multiple kinds of behavior. these should be split into child classes, or be injected following a Manager/AbstractManaged pattern
- you should not find yourself describing functionality in giant code comments. each class should be compartmentalized enough that the name gives away its precise purpose, and classes it's coupled to are named clear enough that its obvious how they are related. if a programmer was to look inside of folder of a module, they would be able to quickly understand roughly all constituent components of the module just by looking at the file names
- if making a small change to a class cascades errors all over the project, the class is not designed well
- MINIMIZE STATE. the class should not become bloated with state. if the class contains lots of state, and groups of the state are catagorically similar, and generally used in tandem in the same operations, the state can probably be extracted into it's own classes
- MINIMIZE COUPLING. how much do classes really need to know about each other? make sure cross-state reading/writing is kept to a minimum, and where it is required is done through a refactorable API surface
- code should describe behavior, not state. do not have embedded configurations hardcoded into dictionaries in the code. if it is nontrivial state, then it should be its own Resource with well defined CRUD operations (or less) on it
- please do not use magic numbers. extract them as consts so they can at least have semantic meaning
- code comments indicate an issue. code should be reasonably self-explanatory. each nontrivial step is labelled by the function name, and sequences of function names detail what the code is doing. code comments also drift when code gets updated.
- code comments are permitted for only: small snippets of highly nontrivial cod

Code Style Guidelines:

- `snake_case` is for variables, functions, fields, and signals.
- `PascalCase` is for class names and script filenames, such as `AbstractEnemy.gd`.
- `SCREAMING_SNAKE_CASE` for constants and enum members.
- private things get a leading `_`, like `_pending` or `_begin_next_level`.
- lifecycle callbacks and fields for managed classes should also start with `_`. they should only be invoked/read by their managers and themselves
- `camelCase` should NOT appear in the codebase.

Integration Guidelines:

- every feature should be its own branch. a feature is focused and relatively small.
- keep your file-touching scope reasonable. be mindful of what others are working on in tandem
- if a PR is merged to main while you are working, or have an outstanding branch, merge it back into your branch and resolve the conflicts
- feel free to keep your PR concise, listing only major features. screenshots + videos are a big bonus and speak more than words

Integration Tools:

- on PR made, Github workflows will verify whether you've adhered to style guidelines, and whether your code compiles in Godot. if either of these fail, the PR will be auto-rejected.