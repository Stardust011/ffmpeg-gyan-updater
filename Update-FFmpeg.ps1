# FFmpeg Git Auto Updater

基于 PowerShell 的 Windows FFmpeg 自动更新脚本，使用 Gyan.dev 提供的 FFmpeg Git Builds。

脚本会自动检测本机已有的 FFmpeg，判断其构建类型和版本，并只在确实需要更新时下载新的 FFmpeg。

## 特性

- 支持 Gyan.dev FFmpeg Git Builds
- 支持 Essentials 和 Full 两种构建
- 支持自动检测当前 FFmpeg 构建类型
- 支持通过参数强制指定构建类型
- 自动在以下位置搜索 FFmpeg：
  - Update-FFmpeg.ps1 所在目录
  - 该目录的所有子目录
  - 系统 PATH
- 不要求 FFmpeg 安装目录名称必须为 ffmpeg
- 自动识别 FFmpeg 实际安装根目录
- 已经是最新版时不下载文件
- 已经是最新版时不会额外请求 SHA-256
- 支持 SHA-256 校验
- 下载支持断点续传
- 使用 .part 文件保存未完成的下载
- 下载完成后才重命名为正式 .7z
- 下载失败时保留 .part
- SHA-256 校验失败时不会安装
- 安装失败时保留 .7z
- 安装成功后自动删除 .7z
- 自动检测 7-Zip
- 不依赖 %TEMP%
- 不使用 /MIR，不会删除 FFmpeg 目录中的其他文件
- 更新时不会删除 Update-FFmpeg.ps1
- 更新完成后自动验证 FFmpeg 版本和构建类型
- 提供一个bat脚本用来双击启动PS1脚本，避免执行策略限制

## 环境要求

### Windows

脚本适用于 Windows PowerShell 5.1 及更高版本。

建议使用现代 Windows 系统，以确保系统自带 curl.exe。

### 7-Zip

脚本需要使用 7-Zip 解压 FFmpeg 的 .7z 文件。

默认会自动搜索：

    %ProgramFiles%\7-Zip\7z.exe
    %ProgramFiles%\7-Zip\7zz.exe
    %ProgramFiles(x86)%\7-Zip\7z.exe
    %ProgramFiles(x86)%\7-Zip\7zz.exe
    %LOCALAPPDATA%\Programs\7-Zip\7z.exe
    %LOCALAPPDATA%\Programs\7-Zip\7zz.exe

同时也会尝试从 PATH 中寻找：

    7z.exe
    7zz.exe

如果找不到 7-Zip，脚本会报错并退出。

## 文件

脚本名称：

    Update-FFmpeg.ps1

例如：

    <FFmpeg安装目录>\
    └─ Update-FFmpeg.ps1

脚本本身不要求必须位于 FFmpeg 安装目录中。

如果脚本没有找到已经安装的 FFmpeg，会使用脚本所在目录作为安装目录。

---

# FFmpeg 自动搜索

脚本启动后会自动寻找已经安装的 FFmpeg。

搜索顺序：

    1. Update-FFmpeg.ps1 所在目录
    2. 该目录的所有子目录
    3. PATH

脚本不会搜索 PowerShell 当前工作目录，除非它正好也是脚本所在目录。

## 脚本所在目录及子目录

脚本会优先检查：

    <脚本目录>\bin\ffmpeg.exe
    <脚本目录>\ffmpeg.exe

如果没有找到，再递归搜索脚本所在目录及其子目录中的 ffmpeg.exe。

递归搜索时会忽略：

    .ffmpeg-update 目录中的 ffmpeg.exe

这是为了避免把解压临时目录中的 FFmpeg 误认为已安装版本。

递归搜索会按完整路径长度排序，优先选择路径较短的 ffmpeg.exe。

## PATH 搜索

如果脚本所在目录及子目录没有找到 FFmpeg，脚本会继续搜索 Windows 的 PATH。

脚本会：

- 读取当前进程的 Path 环境变量
- 展开其中的环境变量
- 在每个目录中查找 ffmpeg.exe
- 跳过 WindowsApps 下的 ffmpeg.exe
- 最后尝试使用 Get-Command ffmpeg.exe 作为补充

WindowsApps 下的 ffmpeg.exe 很可能是 App Execution Alias，不一定代表真正的 FFmpeg 安装目录，因此会被跳过。

## 根目录识别

如果发现：

    <root>\bin\ffmpeg.exe

则：

    <root> = FFmpeg 根目录

如果发现：

    <root>\ffmpeg.exe

则：

    <root> = FFmpeg 根目录

因此 FFmpeg 的安装目录不需要叫 ffmpeg。

以下目录名称都可以：

    FFMPEG
    ffmpeg-git
    ffmpeg-2026
    my-ffmpeg
    video-tools

只要其中存在：

    bin\ffmpeg.exe

即可自动识别。

---

# 构建类型

Gyan.dev 提供多种 FFmpeg Git Build。

本脚本支持：

    Essentials
    Full

## Auto

默认模式：

    .\Update-FFmpeg.ps1

脚本会读取当前 ffmpeg.exe -version 的信息，并自动判断：

    Essentials

或者：

    Full

判断方式：

- 输出中包含 essentials_build，则识别为 Essentials
- 输出中包含 full_build，则识别为 Full
- 如果无法识别，则默认使用 Full

## 强制使用 Essentials

运行：

    .\Update-FFmpeg.ps1 -BuildType Essentials

即使当前安装的是 Full，也会切换到 Essentials。

## 强制使用 Full

运行：

    .\Update-FFmpeg.ps1 -BuildType Full

即使当前安装的是 Essentials，也会切换到 Full。

---

# 版本检查

脚本首先从 Gyan.dev 获取最新版本号。

版本号格式类似：

    <版本号>

例如：

    YYYY-MM-DD-git-<hash>

然后读取本机：

    ffmpeg.exe -version

例如本机返回：

    ffmpeg version <版本号>-full_build-www.gyan.dev

脚本会提取：

    <版本号>

并与 Gyan.dev 的版本进行比较。

## 已经是最新版

当以下两个条件同时满足时：

    本地版本 = Gyan.dev 最新版本
    本地构建类型 = 目标构建类型

脚本会直接结束。

例如：

    [ OK ] Latest Full version: <版本号>
    [INFO] Installed version: <版本号>
    [INFO] Installed build: Full

    [ OK ] FFmpeg is already up to date.

此时：

- 不获取 SHA-256
- 不下载 .7z
- 不解压
- 不复制文件

这样可以避免每次运行脚本都重新下载整个 FFmpeg。

## 构建类型不同

例如：

    本地：
    <版本号>
    Essentials

    目标：
    <版本号>
    Full

虽然版本号相同，但构建类型不同，因此不会认为已经是最新版。

脚本会继续执行更新，将 Essentials 切换为 Full。

---

# SHA-256 校验

只有在确认确实需要更新之后，脚本才会从 Gyan.dev 获取 SHA-256。

例如：

    Expected SHA-256:
    <SHA-256>

下载完成后会重新计算本地文件的 SHA-256。

例如：

    Expected: <SHA-256>
    Actual:   <SHA-256>

只有两者完全一致时才会继续安装。

---

# 下载与断点续传

下载文件使用：

    ffmpeg-git-full.7z

或者：

    ffmpeg-git-essentials.7z

下载过程中使用：

    .part

文件。

例如：

    ffmpeg-git-full.7z.part

只有 curl 正常完成下载后，才会变成：

    ffmpeg-git-full.7z

## 下载中断

如果网络中断：

    ffmpeg-git-full.7z.part

不会删除。

下次运行脚本时，会尝试继续下载，而不是从头开始。

使用的 curl 断点续传参数为：

    -C -

脚本使用的 curl 参数包括：

    --fail
    --location
    --retry 5
    --retry-delay 3
    --connect-timeout 30
    -C -
    --output <part文件>
    <下载地址>

## 已有部分下载

如果脚本发现已经存在 .part 文件，会先计算它的 SHA-256。

如果 .part 本身已经是完整且正确的归档文件，脚本会直接把它恢复为正式 .7z，不再重新下载。

如果 .part 不完整，则使用 curl 续传。

---

# 已有归档文件

如果脚本发现已经存在：

    ffmpeg-git-full.7z

不会直接重新下载。

首先会计算 SHA-256。

如果哈希正确：

    [ OK ] Existing archive is valid.
    [INFO] Skipping download.

然后直接使用这个归档文件。

如果哈希不正确：

    [WARN] SHA-256 verification failed.

脚本会删除损坏的 .7z，然后重新下载。

---

# 安装目录结构

脚本支持多种 FFmpeg 目录结构。

## 仅有 bin

例如：

    <FFmpeg安装目录>\
    ├─ bin\
    │  ├─ ffmpeg.exe
    │  ├─ ffprobe.exe
    │  └─ ffplay.exe
    └─ Update-FFmpeg.ps1

这种情况下更新时只替换：

    bin\*.exe

不会修改其他文件。

## 完整 FFmpeg 目录

如果目标目录同时存在：

    bin
    doc
    presets
    LICENSE
    README.txt

例如：

    <FFmpeg安装目录>\
    ├─ bin\
    │  ├─ ffmpeg.exe
    │  ├─ ffprobe.exe
    │  └─ ffplay.exe
    ├─ doc\
    ├─ presets\
    ├─ LICENSE
    ├─ README.txt
    └─ Update-FFmpeg.ps1

脚本会认为这是完整 FFmpeg 目录。

更新时会替换：

    bin
    doc
    presets
    LICENSE
    README.txt

但是：

    Update-FFmpeg.ps1

不会被删除或覆盖。

脚本不会删除目标目录中其他无关文件。

## 非标准目录名称

目录名称不影响识别。

例如：

    <自定义FFmpeg目录>\
    ├─ bin\
    ├─ doc\
    ├─ presets\
    ├─ LICENSE
    └─ README.txt

脚本仍然可以识别。

判断 FFmpeg 安装目录的关键是：

    bin\ffmpeg.exe

而不是目录名称。

---

# 安装流程

一次正常更新大致经过以下步骤：

    查找 FFmpeg
          ↓
    识别安装目录
          ↓
    识别 Essentials / Full
          ↓
    查询 Gyan.dev 最新版本
          ↓
    比较本地版本和构建类型
          ↓
    已经是最新？
       ┌──┴──┐
      是     否
      ↓      ↓
    退出   获取 SHA-256
             ↓
         检查已有 .7z
             ↓
         检查已有 .part
             ↓
          下载/续传
             ↓
          SHA-256 校验
             ↓
            解压
             ↓
         检查 FFmpeg 文件
             ↓
           安装
             ↓
        验证版本和构建类型
             ↓
           清理文件
             ↓
           更新完成

安装时会检查解压后的 bin 目录中是否存在：

    ffmpeg.exe
    ffprobe.exe
    ffplay.exe

缺少任意一个都会导致安装失败，并保留 .7z。

---

# 更新失败时的文件保留策略

为了避免因为网络中断或安装失败导致无法继续更新，本脚本不会随意删除下载文件。

### 下载中断

保留：

    ffmpeg-git-full.7z.part

下一次运行时可以继续下载。

### SHA-256 错误

不会安装错误文件。

错误的 .7z 会被删除并重新下载。

### 解压失败

保留：

    ffmpeg-git-full.7z

方便后续再次运行。

### 安装失败

保留：

    ffmpeg-git-full.7z

不会进行自动回滚。

### 安装成功

安装成功并验证通过后，会删除：

    ffmpeg-git-full.7z
    .ffmpeg-update

---

# 工作目录

脚本不会使用：

    %TEMP%

解压过程在 FFmpeg 安装目录内部建立：

    .ffmpeg-update

例如：

    <FFmpeg安装目录>\
    ├─ .ffmpeg-update\
    ├─ bin\
    └─ Update-FFmpeg.ps1

安装成功后：

    .ffmpeg-update

会自动删除。

---

# 安全的文件替换

脚本不会使用：

    robocopy /MIR

因为 /MIR 会按照源目录镜像目标目录，可能删除目标目录中原本存在的其他文件。

本脚本只替换 FFmpeg 自身需要更新的内容，因此不会因为更新 FFmpeg 而删除：

    Update-FFmpeg.ps1

或者其他无关文件。

安装时：

- 始终替换目标 bin 目录中的 .exe 文件
- 如果目标是完整布局，则同时复制 doc、presets、LICENSE、README.txt
- 复制目录时使用 Copy-Item -Recurse -Force
- 不会主动删除目标目录中多余的文件

---

# 使用方法

最简单的运行方式：

    .\Update-FFmpeg.ps1

自动检测：

    Essentials / Full

并自动更新。

强制使用 Full：

    .\Update-FFmpeg.ps1 -BuildType Full

强制使用 Essentials：

    .\Update-FFmpeg.ps1 -BuildType Essentials

---

# PowerShell 执行策略

如果系统禁止执行 .ps1，可以使用：

    powershell.exe -ExecutionPolicy Bypass -File .\Update-FFmpeg.ps1

或者根据自己的系统策略调整 PowerShell Execution Policy。

---

# 示例输出

## 已经是最新版

    ============================================
     FFmpeg Git Auto Updater
     Gyan.dev
    ============================================

    [INFO] Found FFmpeg in current directory tree:
           <FFmpeg安装目录>\bin\ffmpeg.exe

    [INFO] Detected FFmpeg root directory:
           <FFmpeg安装目录>

    [INFO] Installed version:
           <版本号>

    [INFO] Installed build type:
           Full

    [INFO] Build type selection: Auto
    [ OK ] Detected installed build type: Full
    [ OK ] Target build type: Full

    [INFO] Checking Gyan.dev for the latest Full Git build...
    [ OK ] Latest Full version: <版本号>

    [ OK ] FFmpeg is already up to date.
           Build:    Full
           Version:  <版本号>
           Location: <FFmpeg安装目录>

这种情况下不会下载 FFmpeg。

---

# 项目目录示例

推荐的简单目录：

    <FFmpeg安装目录>\
    └─ Update-FFmpeg.ps1

如果 FFmpeg 已经安装：

    <FFmpeg安装目录>\
    ├─ bin\
    │  ├─ ffmpeg.exe
    │  ├─ ffprobe.exe
    │  └─ ffplay.exe
    ├─ doc\
    ├─ presets\
    ├─ LICENSE
    ├─ README.txt
    └─ Update-FFmpeg.ps1

也可以使用非标准目录名称：

    <自定义FFmpeg目录>\
    ├─ bin\
    ├─ doc\
    ├─ presets\
    ├─ LICENSE
    ├─ README.txt
    └─ ...

只要 ffmpeg.exe 能被脚本搜索到即可。

---

# 注意事项

首次使用时建议确保：

1. Windows 可以正常运行 curl.exe
2. 已安装 7-Zip
3. 网络可以访问 Gyan.dev
4. FFmpeg 没有被其他程序长期占用

尤其是在 FFmpeg 正被播放器或其他程序使用的情况下，更新某些 .exe 文件可能会失败。

关闭正在使用 FFmpeg 的程序后再次运行即可。

脚本成功时返回退出码 0，失败时返回退出码 1。

---

# 数据来源

FFmpeg Git Builds：

Gyan.dev FFmpeg Builds

https://www.gyan.dev/ffmpeg/builds/

FFmpeg 官方项目：

https://ffmpeg.org/

---

# License

本项目脚本本身的授权方式由项目维护者自行决定。

FFmpeg 本身遵循其对应的自由软件许可证。具体许可证和构建选项请以 FFmpeg 官方项目及所使用 Gyan.dev 构建包中的 LICENSE / README.txt 为准。