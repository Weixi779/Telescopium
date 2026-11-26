# Telescopium

[![CI](https://github.com/Weixi779/Telescopium/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/Weixi779/Telescopium/actions/workflows/ci.yml)
![Platforms](https://img.shields.io/badge/platform-iOS%20%7C%20macOS%20%7C%20tvOS%20%7C%20watchOS-blue)
![Swift](https://img.shields.io/badge/Swift-6.2%2B-orange)
![Swift Package Manager](https://img.shields.io/badge/SwiftPM-supported-brightgreen)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue)](LICENSE)

[English](README.md) | 简体中文

Telescopium 为 Apple 平台的 Swift 应用提供结构化日志与链路追踪。Swift package 只发布一个 library，第三方依赖为零。

- 日志默认写入 Apple 统一日志系统。宿主也可以用自己的 exporter 接收结构化记录。
- 用 `withSpan` 跟踪同步或异步操作，嵌套请求和抛错都由同一个作用域管理。
- 在 App 里配置 `OSSignposter`，就能在 Instruments 中看到 span 的起止区间。

## 安装

需要 Swift tools 6.2 或以上（Xcode 26+）。最低系统版本为 iOS 16、macOS 13、tvOS 16、watchOS 9。

发布 `0.1.0` 标签后，可以在 Xcode 的 **Package Dependencies** 中添加仓库，也可以在 SwiftPM 的包依赖中加入以下声明。

```swift
.package(url: "https://github.com/Weixi779/Telescopium.git", from: "0.1.0")
```

标签发布前，可以用 `.package(path: "../Telescopium")` 引入本地 checkout。两种方式使用同一个 target 依赖。

```swift
.product(name: "Telescopium", package: "Telescopium")
```

## 快速开始

把这段代码放进 Swift 可执行程序的 `main.swift` 就能运行。接入 App 时，在启动处注册一次 exporter，把 logger 留在使用它的业务模块。

```swift
import Foundation
import Telescopium

struct ConsoleSpanExporter: SpanExporter {
    func export(_ record: SpanRecord) {
        print(record.name, record.duration)
    }
}

Trace.register(tracer: TelescopiumTracer(exporter: ConsoleSpanExporter()))

let logger = Logger(category: "Playback")
let payload = Data(#"["Introduction", "Interview"]"#.utf8)

try withSpan("Decode chapters") { _ in
    let chapters = try JSONDecoder().decode([String].self, from: payload)
    logger.info("Loaded chapters", metadata: ["count": chapters.count])
}
```

这段代码产生两份输出。打开「控制台」（Console），启用 Info 级别的消息，再按 category `Playback` 筛选，可以找到对应日志。默认 exporter 将正文标记为 private，具体可见内容取决于系统日志配置。解码结束时，span exporter 会在标准输出打印 `Decode chapters` 和耗时。

如果还想让每条日志带上当前 span 的 ID，可以按[日志关联示例](docs/logging_CN.md#在打日志时关联当前-span)注册宿主的 enricher。

## 文档

- [日志](docs/logging_CN.md) · 设置 category 和 metadata，给记录补充上下文、脱敏，配置导出目的地。
- [追踪](docs/tracing_CN.md) · 跟踪请求和页面生命周期，传递 W3C header，在 Instruments 中查看区间。
- [设计决策](docs/design_CN.md) · 配置在哪里读取，谁持有活跃 span，谁负责交付记录。

## 开发

安装 SwiftFormat 和 SwiftLint 后，在包根目录运行以下检查。

```sh
swift test
swift test -c release
swiftformat --lint Package.swift Sources Tests
swiftlint lint --strict Package.swift Sources Tests
```

[CI workflow](.github/workflows/ci.yml) 固定了工具版本，在 macOS 上运行测试，并为 iOS、tvOS 和 watchOS 编译 library。

## 许可证

采用 [Apache License 2.0](LICENSE)。版权归属见 [NOTICE](NOTICE)。
