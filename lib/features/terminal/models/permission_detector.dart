/// Regex targeting Claude Code permission prompts.
///
/// Version-sensitive: Claude Code output format may change across releases.
/// Named kPermissionPattern (k prefix = compile-time constant per Dart convention).
/// Update this constant when Claude Code changes its permission message format.
///
/// Current target: Claude Code >=1.x permission prompt formats including
/// "Do you want to", "Allow [tool] to", "Approve [action]", (y/n), [y/n],
/// checkbox-style "✓ Yes", and "yes/no" confirmation patterns.
const kPermissionPattern =
    r'(Do you want to|Allow .+ to|Approve .+|\(y\/n\)|\[y\/n\]|✓ Yes|yes\/no)';
