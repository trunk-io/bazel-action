load("//:txt.bzl", "txt_library")

txt_library(
    name = "lib3",
    srcs = ["foo.txt"],
    deps = ["//lib2"],
    visibility = ["//visibility:public"],
)
