# 日志

[English](logging.md) · [文档首页](../README_CN.md#文档)

业务模块持有自己的 `Logger`，App 负责组装处理步骤和选择出口。使用默认配置时，创建 logger 后就可以把日志写入 Apple 统一日志系统。

## 分类、元数据与错误

```swift
import Telescopium

let playback = Logger(
    category: "Playback",
    metadata: ["module": "Playback", "request": ["attempt": 1, "cached": true]]
)
playback.info(
    "Retrying request",
    metadata: ["request": ["attempt": 2], "delays_ms": [100, 200]]
)
```

这条记录保留了 `module = Playback`。本次调用传入的 `request` 会把整个对象替换为 `["attempt": 2]`。下次打日志时，logger 仍然使用初始化时的默认值。数组也按顶层 key 整体替换。

subsystem 取自主 bundle 的标识符，取不到时用 `"app"`。默认 category 是 `"Default"`。每条记录在调用处捕获时间、级别、正文、文件 ID、函数、行号和列号。五个级别的方法都接受可选的 `error:`。生成的 `ErrorInfo` 保留具体类型名和错误消息。对于 `NSError` 或遵循 `CustomNSError` 的错误，还会保留 domain 和 code。普通 Swift 错误的这两个字段均为 `nil`。

### Exporter 收到的值

Logger 在初始化和单次调用时都接受 `[String: Any]`。在交给 enricher 之前，它会把字段转换为 `Metadata`，也就是 `[String: MetadataValue]`。Exporter 可以直接对枚举值做模式匹配。

| 输入 | 存入记录的值 |
| --- | --- |
| `Bool`、字符串 | `.bool`、`.string` |
| 可用 `Int64` 表示的整数 | `.int` |
| `Float`、`Double` | `.double` |
| `Data` | `.bytes` |
| `NSNull()`、`MetadataValue.null` | `.null` |
| 数组、字符串键字典 | `.array`、`.object`，递归转换子节点 |

转换会跳过不支持的值，包括 `Decimal`、超出 `Int64` 范围的整数，以及 Foundation 容器中的循环引用。其余数组元素保持相对顺序。Debug 构建会记录被跳过的值所在的路径。手动转换字典用 `Metadata(converting:)`，单个值用 `MetadataValue(converting:)`。

`LogRecord` 遵循 `Equatable` 和 `Codable`。编码时每个 metadata 节点都带有类型标签，例如整数编码为 `{"int":2}`，字节数据编码为 `bytes` 标签下的 Base64 字符串。解码时能还原任意嵌套深度的原始类型。后端有自己的 JSON 格式时，由 exporter 把枚举值映射到对应字段。

## 创建记录前过滤级别

App 可以在启动时配置最低级别，例如 `Log.register(recorder: LogRecorder(minimumLevel: .info))`。由这个 recorder 接收的 `debug` 调用会提前返回，消息插值和本次 metadata 表达式都会跳过。级别通过时，这两个表达式各自在调用线程上同步求值一次。业务必须执行的操作应放在日志表达式外。涉及 `try` 或 `await` 的参数先行计算，再将结果传入 logger。

内置 recorder 的最低级别默认为 `.debug`。出口列表为空时，它会拒绝所有级别。自定义 recorder 默认接受全部级别，也可以实现 `isEnabled(for:)` 来决定接收哪些级别。Apple 统一日志是否启用由末端的 `OSLogExporter` 单独检查。

## 在打日志时关联当前 span

在 App 里定义 enricher。它在打日志的调用方上下文中运行，此时还能从 task-local 作用域读到当前 span，把身份信息复制进新记录。

```swift
import Telescopium

struct CurrentSpanEnricher: LogEnricher {
    func process(_ record: LogRecord) -> LogRecord {
        var result = record
        result.traceParent = record.traceParent ?? TraceScope.current?.traceParent
        return result
    }
}

Log.register(recorder: LogRecorder(), enrichers: [CurrentSpanEnricher()])
```

`withSpan` 里面发出的日志会保留这个 span 的 `TraceParent`，延后读取记录也能拿到同一个值。在 span 外打日志会保留记录已有的 parent，通常是 `nil`。即使使用只传播上下文的默认 tracer，这个关联也成立。结构化 exporter 可以直接从记录读取两个 ID。

## 脱敏与导出

下面的 App 先移除顶层 `token` 字段，再把同一份结果送到两个出口。其中一个 exporter 只打印 category、级别和 trace ID。注册时一起传入上面定义的 enricher。

```swift
struct RemoveToken: LogRedactor {
    let policy: RedactionPolicy = .always

    func process(_ record: LogRecord) -> LogRecord {
        var result = record
        result.metadata.removeValue(forKey: "token")
        return result
    }
}

struct CorrelationExporter: LogExporter {
    func export(_ record: LogRecord) {
        let traceID = record.traceParent?.traceId.hexString ?? "none"
        print(record.category, record.level.rawValue, traceID)
    }
}

Log.register(
    recorder: LogRecorder(
        redactors: [RemoveToken()],
        exporters: [OSLogExporter(), CorrelationExporter()]
    ),
    enrichers: [CurrentSpanEnricher()]
)

withSpan("Refresh queue") { _ in
    Logger(category: "Playback").info("Queue refreshed")
}
```

每次调用 `Log.register` 都会一起替换 recorder 和有序的 enricher 列表。一条日志依次经历以下步骤。

1. Logger 为本次调用读取一次 App 配置，询问显式绑定的 recorder 是否接收该级别。没有显式绑定时，询问当前 App recorder。
2. 级别通过后，logger 创建记录，在调用线程上按顺序运行这次读取的 enrichers，并将结果交给先前选定的 recorder。
3. 内置的 `LogRecorder` 按顺序运行启用的 redactor。策略有 `.always`、`.never` 和每次处理记录时求值的 `.when { … }`。随后各 exporter 按配置顺序同步收到同一份最终记录。不同日志调用可以并发执行。

要添加一个目的地，实现 `LogExporter` 即可。要接管整个记录过程，包括脱敏和交付策略，可以实现 `LogRecording`。Enricher 和 redactor 共用公开的 `LogRecordProcessor.process(_:)`，宿主也可以组装自己的处理链。注册 `LogRecorder(exporters: [])` 可以关闭 App 默认 recorder 的输出。

## Apple 统一日志

| 记录级别 | Apple 日志类型 |
| --- | --- |
| `debug` | `.debug` |
| `info` | `.info` |
| `warning`、`error` | `.error` |
| `fault` | `.fault` |

`OSLogExporter` 先检查映射后的级别是否启用，再格式化文本。写入系统的 private 文本包括消息、可选的错误类型与描述，以及调用位置。结构化 exporter 可以另行读取 metadata 和 trace ID。在 Debug 和 Release 构建中，通过过滤的记录都会保留原始级别。统一日志的可见性和保留策略由系统配置决定。
