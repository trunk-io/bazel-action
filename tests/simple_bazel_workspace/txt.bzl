FileInfo = provider(doc = "", fields = ["transitive_sources"])

def _txt_library_impl(ctx):
    trans_srcs = depset(
        ctx.files.srcs,
        transitive = [dep[FileInfo].transitive_sources for dep in ctx.attr.deps],
    )
    return [
        FileInfo(transitive_sources = trans_srcs),
        DefaultInfo(files = trans_srcs),
    ]

txt_library = rule(
    implementation = _txt_library_impl,
    attrs = {
        "deps": attr.label_list(),
        "srcs": attr.label_list(allow_files = [".txt"]),
    },
)
