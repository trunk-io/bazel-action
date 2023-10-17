load("//:txt.bzl", "txt_library")

txt_library(
    name = "lib12",
    srcs = ["foo.txt"],
    visibility = ["//visibility:public"],
    deps = [
        "//lib13",
        "//lib14",
    ],
)
