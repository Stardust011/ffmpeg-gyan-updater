# FFmpeg Git Auto Updater

基于 PowerShell 的 Windows FFmpeg 自动更新脚本，使用 [Gyan.dev](https://www.gyan.dev/ffmpeg/builds/) 提供的 FFmpeg Git Builds。

脚本会自动检测本机已有的 FFmpeg，判断其构建类型和版本，并只在确实需要更新时下载新的 FFmpeg。

## 特性

* 支持 Gyan.dev FFmpeg Git Builds
* 支持 `Essentials` 和 `Full` 两种构建
* 支持自动检测当前 FFmpeg 构建类型
* 支持通过参数强制指定构建类型
* 自动在以下位置搜索 FFmpeg：

  * 当前脚本所在目录
  * 当前目录的所有子目录
  * 系统 `PATH`
* 不要求 FFmpeg 安装目录名称必须为 `ffmpeg`
* 自动识别 FFmpeg 实际安装根目录
* 已经是最新版时不下载文件
* 已经是最新版时不会额外请求 SHA-256
* 支持 SHA-256 校验
* 下载支持断点续传
* 使用 `.part` 文件保存未完成的下载
* 下载完成后才重命名为正式 `.7z`
* 下载失败时保留 `.part`
* SHA-256 校验失败时不会安装
* 安装失败时保留 `.7z`
* 安装成功后自动删除 `.7z`
* 自动检测 7-Zip
* 不依赖 `%TEMP%`
* 不使用 `/MIR`，不会删除 FFmpeg 目录中的其他文件
* 更新时不会删除 `Update-FFmpeg.ps1`
* 更新完成后自动验证 FFmpeg 版本和构建类型

## 环境要求

### Windows

脚本适用于 Windows PowerShell 5.1 及更高版本。

建议使用现代 Windows 系统，以确保系统自带 `curl.exe`。

### 7-Zip

脚本需要使用 7-Zip 解压 FFmpeg 的 `.7z` 文件。

默认会自动搜索：

```text
C:\Program Files\7-Zip\7z.exe
C:\Program Files\7-Zip\7zz.exe
C:\Program Files (x86)\7-Zip\7z.exe
C:\Program Files (x86)\7-Zip\7zz.exe
```

同时也会尝试从 `PATH` 中寻找：

```text
7z.exe
7zz.exe
```

## 文件

脚本名称：

```text
Update-FFmpeg.ps1
```

例如：

```text
<FFmpeg安装目录>\
└─ Update-FFmpeg.ps1
```

脚本本身不要求必须位于 FFmpeg 安装目录中。

---

# FFmpeg 自动搜索

脚本启动后会自动寻找已经安装的 FFmpeg。

搜索顺序：

```text
1. Update-FFmpeg.ps1 所在目录
2. 该目录的所有子目录
3. PATH
```

例如脚本位于：

```text
<脚本目录>\Update-FFmpeg.ps1
```

脚本会搜索：

```text
<脚本目录>\ffmpeg.exe
<脚本目录>\bin\ffmpeg.exe
<脚本目录>\FFMPEG\bin\ffmpeg.exe
<脚本目录>\Tools\ffmpeg\bin\ffmpeg.exe
<脚本目录>\SomeOtherName\bin\ffmpeg.exe
```

因此 FFmpeg 的安装目录不需要叫：

```text
ffmpeg
```

以下目录名称都可以：

```text
FFMPEG
ffmpeg-git
ffmpeg-2026
my-ffmpeg
video-tools
```

只要其中存在：

```text
bin\ffmpeg.exe
```

即可自动识别。

## PATH 搜索

如果脚本所在目录及子目录没有找到 FFmpeg，脚本会继续搜索 Windows 的 `PATH`。

例如：

```text
<PATH中的FFmpeg目录>
<PATH中的另一个FFmpeg目录>
```

只要这些目录在 `PATH` 中并存在：

```text
ffmpeg.exe
```

即可被发现。

---

# 构建类型

Gyan.dev 提供多种 FFmpeg Git Build。

本脚本支持：

```text
Essentials
Full
```

## Auto

默认模式：

```powershell
.\Update-FFmpeg.ps1
```

脚本会读取当前 `ffmpeg.exe -version` 的信息，并自动判断：

```text
Essentials
```

或者：

```text
Full
```

如果无法识别，则默认使用：

```text
Full
```

---

# 强制使用 Essentials

运行：

```powershell
.\Update-FFmpeg.ps1 -BuildType Essentials
```

即使当前安装的是 Full，也会切换到 Essentials。

---

# 强制使用 Full

运行：

```powershell
.\Update-FFmpeg.ps1 -BuildType Full
```

即使当前安装的是 Essentials，也会切换到 Full。

---

# 版本检查

脚本首先从 Gyan.dev 获取最新版本号。

例如：

```text
<版本号>
```

然后读取本机：

```text
ffmpeg.exe -version
```

例如本机返回：

```text
ffmpeg version <版本号>-full_build-www.gyan.dev
```

脚本会提取：

```text
<版本号>
```

并与 Gyan.dev 的版本进行比较。

## 已经是最新版

当以下两个条件同时满足时：

```text
本地版本 = Gyan.dev 最新版本
本地构建类型 = 目标构建类型
```

脚本会直接结束。

例如：

```text
[ OK ] Latest Full version: <版本号>
[INFO] Installed version: <版本号>
[INFO] Installed build: Full

[ OK ] FFmpeg is already up to date.
```

此时：

* 不获取 SHA-256
* 不下载 `.7z`
* 不解压
* 不复制文件

这样可以避免每次运行脚本都重新下载整个 FFmpeg。

---

# 构建类型不同

例如：

```text
本地：
<版本号>
Essentials

目标：
<版本号>
Full
```

虽然版本号相同，但构建类型不同，因此不会认为已经是最新版。

脚本会继续执行更新，将 Essentials 切换为 Full。

---

# SHA-256 校验

只有在确认确实需要更新之后，脚本才会从 Gyan.dev 获取 SHA-256。

例如：

```text
Expected SHA-256:
<SHA-256>
```

下载完成后会重新计算本地文件的 SHA-256。

例如：

```text
Expected: <SHA-256>
Actual:   <SHA-256>
```

只有两者完全一致时才会继续安装。

---

# 下载与断点续传

下载文件使用：

```text
ffmpeg-git-full.7z
```

或者：

```text
ffmpeg-git-essentials.7z
```

下载过程中使用：

```text
.part
```

文件。

例如：

```text
ffmpeg-git-full.7z.part
```

只有 curl 正常完成下载后，才会变成：

```text
ffmpeg-git-full.7z
```

## 下载中断

如果网络中断：

```text
ffmpeg-git-full.7z.part
```

不会删除。

下次运行脚本时，会尝试继续下载，而不是从头开始。

使用的 curl 断点续传参数为：

```text
-C -
```

---

# 已有归档文件

如果脚本发现已经存在：

```text
ffmpeg-git-full.7z
```

不会直接重新下载。

首先会计算 SHA-256。

如果哈希正确：

```text
[ OK ] Existing archive is valid.
[INFO] Skipping download.
```

然后直接使用这个归档文件。

如果哈希不正确：

```text
[WARN] SHA-256 verification failed.
```

脚本会删除损坏的 `.7z`，然后重新下载。

---

# 安装目录结构

脚本支持多种 FFmpeg 目录结构。

## 仅有 bin

例如：

```text
<FFmpeg安装目录>\
├─ bin\
│  ├─ ffmpeg.exe
│  ├─ ffprobe.exe
│  └─ ffplay.exe
└─ Update-FFmpeg.ps1
```

这种情况下更新时只替换：

```text
bin\*.exe
```

不会修改其他文件。

---

## 完整 FFmpeg 目录

如果目标目录同时存在：

```text
bin
doc
presets
LICENSE
README.txt
```

例如：

```text
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
```

脚本会认为这是完整 FFmpeg 目录。

更新时会替换：

```text
bin
doc
presets
LICENSE
README.txt
```

但是：

```text
Update-FFmpeg.ps1
```

不会被删除或覆盖。

---

# 非标准目录名称

目录名称不影响识别。

例如：

```text
<自定义FFmpeg目录>\
├─ bin\
├─ doc\
├─ presets\
├─ LICENSE
└─ README.txt
```

脚本仍然可以识别。

判断 FFmpeg 安装目录的关键是：

```text
bin\ffmpeg.exe
```

而不是目录名称。

---

# 安装流程

一次正常更新大致经过以下步骤：

```text
查找 FFmpeg
      ↓
识别安装目录
      ↓
识别 Essentials / Full
      ↓
查询 Gyan.dev 最新版本
      ↓
比较本地版本
      ↓
已经是最新？
   ┌──┴──┐
  是     否
  ↓      ↓
退出   获取 SHA-256
         ↓
     检查已有 .7z
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
```

---

# 更新失败时的文件保留策略

为了避免因为网络中断或安装失败导致无法继续更新，本脚本不会随意删除下载文件。

### 下载中断

保留：

```text
ffmpeg-git-full.7z.part
```

下一次运行时可以继续下载。

### SHA-256 错误

不会安装错误文件。

错误的 `.7z` 会被删除并重新下载。

### 解压失败

保留：

```text
ffmpeg-git-full.7z
```

方便后续再次运行。

### 安装失败

保留：

```text
ffmpeg-git-full.7z
```

不会进行自动回滚。

---

# 工作目录

脚本不会使用：

```text
%TEMP%
```

解压过程在 FFmpeg 安装目录内部建立：

```text
.ffmpeg-update
```

例如：

```text
<FFmpeg安装目录>\
├─ .ffmpeg-update\
├─ bin\
└─ Update-FFmpeg.ps1
```

安装成功后：

```text
.ffmpeg-update
```

会自动删除。

---

# 安全的文件替换

脚本不会使用：

```text
robocopy /MIR
```

因为 `/MIR` 会按照源目录镜像目标目录，可能删除目标目录中原本存在的其他文件。

本脚本只替换 FFmpeg 自身需要更新的内容，因此不会因为更新 FFmpeg 而删除：

```text
Update-FFmpeg.ps1
```

或者其他无关文件。

---

# 使用方法

最简单的运行方式：

```powershell
.\Update-FFmpeg.ps1
```

自动检测：

```text
Essentials / Full
```

并自动更新。

强制使用 Full：

```powershell
.\Update-FFmpeg.ps1 -BuildType Full
```

强制使用 Essentials：

```powershell
.\Update-FFmpeg.ps1 -BuildType Essentials
```

---

# PowerShell 执行策略

如果系统禁止执行 `.ps1`，可以使用：

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Update-FFmpeg.ps1
```

或者根据自己的系统策略调整 PowerShell Execution Policy。

---

# 示例输出

## 已经是最新版

```text
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
```

这种情况下不会下载 FFmpeg。

---

# 项目目录示例

推荐的简单目录：

```text
<FFmpeg安装目录>\
└─ Update-FFmpeg.ps1
```

如果 FFmpeg 已经安装：

```text
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
```

也可以使用非标准目录名称：

```text
<自定义FFmpeg目录>\
├─ bin\
├─ doc\
├─ presets\
├─ LICENSE
├─ README.txt
└─ ...
```

只要 `ffmpeg.exe` 能被脚本搜索到即可。

---

# 注意事项

首次使用时建议确保：

1. Windows 可以正常运行 `curl.exe`
2. 已安装 7-Zip
3. 网络可以访问 Gyan.dev
4. FFmpeg 没有被其他程序长期占用

尤其是在 FFmpeg 正被播放器或其他程序使用的情况下，更新某些 `.exe` 文件可能会失败。

关闭正在使用 FFmpeg 的程序后再次运行即可。

---

# 数据来源

FFmpeg Git Builds：

Gyan.dev FFmpeg Builds

https://www.gyan.dev/ffmpeg/builds/

FFmpeg 官方项目：

https://ffmpeg.org/

---

# License

本项目脚本本身的授权方式为MIT协议。

FFmpeg 本身遵循其对应的自由软件许可证。具体许可证和构建选项请以 FFmpeg 官方项目及所使用 Gyan.dev 构建包中的 LICENSE / README.txt 为准。
