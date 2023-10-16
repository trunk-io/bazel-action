load("//:txt.bzl", "txt_library")

txt_library(
    name = "lib",
    srcs = ["foo.txt"],
    deps = [
        "//lib2",
        "//lib3",
    ],
    visibility = ["//visibility:public"],
)
