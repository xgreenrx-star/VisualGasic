Dual Kawase demo — Missing / noteworthy keywords and limitations

Notes about porting the Dual Kawase blur plugin to VisualGasic demos:

- Compositor API: VisualGasic currently does not expose a high-level "Compositor" keyword or dedicated built-in for attaching compositor effects to viewports. Applying the Dual Kawase compositor typically requires editor setup (attach to the Compositor or autoload) and then referencing the node instance from VisualGasic.

- Node creation: There is no documented single-line "CreateNode" / "AddChild" VisualGasic keyword equivalent; you should add the required nodes in the scene in the editor, name them (e.g., "DualKawase"), and the form auto-wires them into the script scope at runtime.

- Shader/Resource constructors: If the upstream plugin requires programmatically creating ShaderMaterial or CompositorEffect instances, VisualGasic does not currently provide shorthand keywords for their constructors; you can either (a) pre-create resources in the scene, or (b) call into helper GDScript glue if available.

- Boolean type: For portability, some examples use Integer (0/1) for enabled flags; if Boolean support differs between target environments, adapt accordingly.

If you'd like, I can add lightweight helper GDScript bridge functions (e.g., `CreateCompositorEffect(name)` and `ApplyCompositorToViewport(viewport, effect)`) in `examples/AssetLib/dual_kawase/upstream/bridges/` to expose missing APIs to VisualGasic in a clean way.