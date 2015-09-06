%% Specific modules to include in cover.
{
 incl_mods,
 [
  'clj_analyzer',
  'clj_compiler',
  'clj_core',
  'clj_emitter',
  'clj_env',
  'clj_namespace',
  'clj_reader',
  'clj_utils',
  'clojerl.Keyword.clojerl.IMeta',
  'clojerl.Keyword.clojerl.Named',
  'clojerl.Keyword',
  'clojerl.protocol',
  'clojerl.Symbol.clojerl.IMeta',
  'clojerl.Symbol.clojerl.Named',
  'clojerl.Symbol.clojerl.Stringable',
  'clojerl.Symbol',
  'clojerl.Var.clojerl.IDeref',
  'clojerl.Var',
  'clojerl.List.clojerl.Counted',
  'clojerl.List.clojerl.ISeq',
  'clojerl.List',
  'clojerl.Map.clojerl.Counted',
  'clojerl.Map',
  'clojerl.Set.clojerl.Counted',
  'clojerl.Set',
  'clojerl.Vector.clojerl.Counted',
  'clojerl.Vector.clojerl.ISeq',
  'clojerl.Vector',
  'clojerl.Counted',
  'clojerl.IDeref',
  'clojerl.ILookup',
  'clojerl.IMeta',
  'clojerl.ISeq',
  'clojerl.Named',
  'clojerl.Stringable'
 ]
}.
%% Export coverage data for jenkins.
{export, "logs/cover.data"}.
