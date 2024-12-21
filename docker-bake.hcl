function "default_distros" {
  params = []
  result = ["noble"]
}
function "default_qbs_versions" {
  params = []
  result = ["2.3.1", "2.4.2", "2.5.0"]
}
function "default_clangs" {
  params = []
  result = [
    {major: 17, source: "apt"},
    {major: 18, source: "llvm"},
    {major: 19, source: "llvm"}
  ]
}
function "default_gccs" {
  params = []
  result = [
    {major: 12, source: "apt"},
    {major: 13, source: "apt"},
    {major: 14, source: "apt"}
  ]
}
function "default_qts" {
  params = []
  result = [
    {version: "6.6.3", arch: "gcc_64"},
    {version: "6.7.3", arch: "linux_gcc_64"},
    {version: "6.8.1", arch: "linux_gcc_64"}
  ]
}
function "targets" {
  params = []
  result = [
    "qbs-gcc",
    "qbs-gcc-qt",
    # "qbs-gcc-qtgui-dev",
    "qbs-clang",
    "qbs-clang-libstdcpp",
    "qbs-clang-libstdcpp-qt",
    # "qbs-clang-libstdcpp-qtgui-dev"
  ]
}

variable "DISTROS" {
  default = jsonencode(default_distros())
  # default = jsonencode([default_distros()[length(default_distros()) - 1]]) # only latest
}
variable "ALL_DISTROS" {
  default = jsonencode(default_distros())
}
function "distros" {
  params = []
  result = jsondecode(ALL_DISTROS)
}
function "matrix_distros" {
  params = []
  result = jsondecode(DISTROS)
}

variable "QBS_VERSIONS" {
  default = jsonencode(default_qbs_versions())
  # default = jsonencode([default_qbs_versions()[length(default_qbs_versions()) - 1]]) # only latest
}
variable "ALL_QBS_VERSIONS" {
  default = jsonencode(default_qbs_versions())
}
function "qbs_versions" {
  params = []
  result = jsondecode(ALL_QBS_VERSIONS)
}
function "matrix_qbs_versions" {
  params = []
  result = jsondecode(QBS_VERSIONS)
}

variable "CLANGS" {
  default = jsonencode(default_clangs())
  # default = jsonencode([default_clangs()[length(default_clangs()) - 1]]) # only latest
}
variable "ALL_CLANGS" {
  default = jsonencode(default_clangs())
}
function "clangs" {
  params = []
  result = jsondecode(ALL_CLANGS)
}
function "matrix_clangs" {
  params = [target]
  result = length(regexall("-clang(?:-|$)", target)) > 0 ? jsondecode(CLANGS) : [{major: "", source: ""}]
}

variable "GCCS" {
  default = jsonencode(default_gccs())
  # default = jsonencode([default_gccs()[length(default_gccs()) - 1]]) # only latest
}
variable "ALL_GCCS" {
  default = jsonencode(default_gccs())
}
function "gccs" {
  params = []
  result = jsondecode(ALL_GCCS)
}
function "matrix_gccs" {
  params = [target]
  result = length(regexall("-(?:gcc|libstdcpp)(?:-|$)", target)) > 0 ? jsondecode(GCCS) : [{major: "", source: ""}]
}

variable "QTS" {
  default = jsonencode(default_qts())
  # default = jsonencode([default_qts()[length(default_qts()) - 1]]) # only latest
}
variable "ALL_QTS" {
  default = jsonencode(default_qts())
}
function "qts" {
  params = []
  result = jsondecode(ALL_QTS)
}
function "matrix_qts" {
  params = [target]
  result = length(regexall("-qt", target)) > 0 ? jsondecode(QTS) : [{version: "", arch: ""}]
}

function "matrix" {
  params = []
  result = flatten([for target in targets() :
    flatten([for distro in matrix_distros() :
      flatten([for qbs_version in matrix_qbs_versions() :
        flatten([for clang in matrix_clangs(target) :
          flatten([for gcc in matrix_gccs(target) :
            [for qt in matrix_qts(target) : {
              target: target,
              distro: distro,
              qbs_version: qbs_version,
              clang: clang,
              gcc: gcc,
              qt: qt
            }]
          ])
        ])
      ])
    ])
  ])
}

function "latestTag" {
  params = [qbs_version, clang_major, gcc_major, qt_version]
  result = (qbs_version == qbs_versions()[length(qbs_versions())-1]
    && (clang_major == "" || "X${clang_major}" == "X${clangs()[length(clangs()) - 1].major}")
    && (gcc_major == "" || "X${gcc_major}" == "X${gccs()[length(gccs()) - 1].major}")
    && (qt_version == "" || qt_version == qts()[length(qts()) - 1].version)) ? "latest" : ""
}
function "versionTag" {
  params = [qbs_version, clang_major, gcc_major, qt_version]
  result = join("-", compact([qbs_version, clang_major, gcc_major, qt_version]))
}
function "tags" {
  params = [target, qbs_version, clang_major, gcc_major, qt_version]
  result = flatten([for tag in compact([versionTag(qbs_version, clang_major, gcc_major, qt_version), latestTag(qbs_version, clang_major, gcc_major, qt_version)]) : [
    "arbmind/${target}:${tag}",
    "ghcr.io/arbmind/${target}:${tag}"
  ]])
}
function "describeClang" {
  params = [major]
  result = major == "" ? "" : "Clang${major}"
}
function "describeGcc" {
  params = [target, major]
  result = major == "" ? "" : (length(regexall("-clang-", target)) > 0 ? "LibStdC++${major}" : "GCC${major}")
}
function "describeQt" {
  params = [target, version]
  result = version == "" ? "" : (length(regexall("qtgui-dev$", target)) > 0 ? "QtGui ${version} + Dev" : "Qt ${version}")
}
function "description" {
  params = [target, distro, qbs_version, clang_major, gcc_major, qt_version]
  result = "Ubuntu ${distro} - ${join(" + ", compact(["Qbs ${qbs_version}", describeClang(clang_major), describeGcc(target, gcc_major), describeQt(target, qt_version)]))}"
}
function "uniqueName" {
  params = [target, distro, qbs_version, clang_major, gcc_major, qt_version]
  result = join("-", compact([target, distro, replace(qbs_version, ".", "_"), clang_major, gcc_major, replace(qt_version, ".", "_")]))
}
function "dockerTarget" {
  params = [target]
  result = length(regexall("qtgui-dev$", target)) > 0 ? "qbs-qtgui-dev" : target
}
function "qtguiBaseImage" {
  params = [target]
  result = length(regexall("-clang-", target)) > 0 ? "qbs-clang-libstdcpp-qt" : "qbs-gcc-qt"
}

target "default" {
  dockerfile = "Dockerfile"
  context = "./"
  target = dockerTarget(matrix.target)
  name = uniqueName(matrix.target, matrix.distro, matrix.qbs_version, matrix.clang.major, matrix.gcc.major, matrix.qt.version)
  tags = tags(matrix.target, matrix.qbs_version, matrix.clang.major, matrix.gcc.major, matrix.qt.version)
  matrix = {
    matrix = matrix()
  }
  args = {
    DISTRO = matrix.distro
    QBS_VERSION = matrix.qbs_version
    CLANG_MAJOR = matrix.clang.major
    CLANG_SOURCE = matrix.clang.source
    GCC_MAJOR = matrix.gcc.major
    GCC_SOURCE = matrix.gcc.source
    QT_VERSION = matrix.qt.version
    QT_ARCH = matrix.qt.arch
    # QTGUI_BASE_IMAGE = qtguiBaseImage(matrix.target)
  }
  labels = {
    "org.opencontainers.image.source" = "https://github.com/arBmind/qbs-containers"
    Description = description(matrix.target, matrix.distro, matrix.qbs_version, matrix.clang.major, matrix.gcc.major, matrix.qt.version)
  }
}
