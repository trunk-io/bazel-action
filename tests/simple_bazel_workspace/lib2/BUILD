load("//:txt.bzl", "txt_library")

txt_library(
    name = "lib2",
    srcs = ["foo.txt"],
    deps = ["//lib0"],
    visibility = ["//visibility:public"],
)
