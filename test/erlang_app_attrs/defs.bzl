"""Loading-time check that erlang_app and ct_suite forward attributes."""

def assert_forwarded(tag, incompatible, untagged = []):
    """Fails the package unless every generated rule carries the tag and the constraint.

    Args:
      tag: a tag passed to erlang_app and ct_suite.
      incompatible: the target_compatible_with label passed to them.
      untagged: rules that only get target_compatible_with.
    """
    rules = native.existing_rules()
    if not rules:
        fail("no rules to check")
    for name, rule in rules.items():
        tags = rule.get("tags") or []
        if name not in untagged and tag not in tags:
            fail("{}: tags {} do not contain {}".format(name, tags, tag))
        tcw = [str(c) for c in (rule.get("target_compatible_with") or [])]
        if not [c for c in tcw if c.endswith(incompatible)]:
            fail("{}: target_compatible_with {} does not contain {}".format(name, tcw, incompatible))
