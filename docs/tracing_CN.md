# 追踪

[English](tracing.md) · [文档首页](../README_CN.md#文档)

一个 span 表示一次操作，由启动它的 tracer 负责结束。`TraceScope.current` 携带最内层 span 的身份，在同步调用和异步挂起前后都可读取。

## 跟踪两个串行请求

由 App 的网络客户端提供 `send`。一次购买产生三个 span。外层是购买操作，里面两个客户端请求依次执行，拥有同一个父 span。每个请求返回时都会恢复购买操作的上下文。

```swift
import Telescopium

func confirmPurchase(send: (String) async throws -> Void) async throws {
    try await withSpan("Confirm purchase") { _ in
        try await withSpan("POST /orders", ofKind: .client) { span in
            span.setMetadata("POST", forKey: "http.method")
            try await send("/orders")
            span.addEvent(SpanEvent("Order accepted"))
        }
        try await withSpan("POST /payments", ofKind: .client) { _ in
            try await send("/payments")
        }
    }
}
```

如果下单请求抛错，当前请求和外层购买操作都会携带该错误结束，恢复调用前的上下文，并跳过支付请求。跟踪同步操作同样使用 `withSpan`。进程内操作用默认的 `.internal`，请求的调用方和服务方分别用 `.client` 和 `.server`，队列任务的生产方和消费方分别用 `.producer` 和 `.consumer`。

## 选择记录内容

默认的 `TelescopiumTracer()` 为每个 span 创建上下文，供子操作和日志关联其身份。需要采集耗时、事件、metadata 和错误时，给它配置一个 `SpanExporter`。在 App 启动时注册 tracer，全局 `withSpan` 便会使用它。已注入 tracer 的组件可以直接调用 `tracer.withSpan`。

```swift
struct TimingExporter: SpanExporter {
    func export(_ record: SpanRecord) {
        print(record.name, record.duration, record.events.map(\.name))
    }
}

let tracer = TelescopiumTracer(exporter: TimingExporter())
Trace.register(tracer: tracer)
```

首次结束时，exporter 会在结束调用的线程上同步收到一条完整的 `SpanRecord`。不同 span 可以并发结束。分析经过的时长用 `duration`，对齐其他事件发生的时间用墙钟时间 `startTime` 和 `endTime`。记录还包含操作名称与 kind、上下文、可选的父 span ID、有序事件、metadata 和可选的 `ErrorInfo`。记录和事件都遵循 `Codable`、`Equatable`。

后端 SDK 需要创建自己的活跃 span 时，可以实现 `Tracer` 并注册该实现。`startSpan(_:ofKind:parent:)` 收到当前作用域的父上下文，返回遵循 `Span` 的句柄。句柄公开新上下文，并把 `setMetadata`、`addEvent` 转发给 SDK。`endSpan(_:throwing:)` 收到同一具体类型的句柄，操作抛错时还会收到原始错误。[为何从创建时接入](design_CN.md#谁创建活跃-span)

## 跨回调持有 span

页面在一个回调中打开，在另一个回调中关闭。可以手动启动页面 span，由页面持有，只在处理属于该页面的操作时将它绑定为 current。这个例子同时保存了创建子请求所用的 tracer。

```swift
final class OrderDetailsScreen {
    private let tracer: any Tracer
    private let page: any Span
    let close: () -> Void

    init(tracer: some Tracer) {
        let page = tracer.startSpan("Order details", ofKind: .internal, parent: TraceScope.current)
        self.tracer = tracer
        self.page = page
        close = { tracer.endSpan(page, throwing: nil) }
    }

    func refresh(load: () async throws -> Void) async throws {
        try await page.withCurrent {
            try await tracer.withSpan("GET /orders/{id}", ofKind: .client) { _ in
                try await load()
            }
        }
    }
}
```

打开页面时创建这个对象，页面对应的生命周期结束时调用 `close()`。`page.withCurrent` 在闭包返回或抛错后恢复外层上下文。之后的刷新仍然可以使用同一个页面 span 作为父级。初始化器把具体 tracer 与它创建的 span 一起捕获在结束闭包中，因此页面可以接收注入的或经过 signpost 装饰的 tracer，页面类型本身可以保持非泛型。

## 跨网络边界传递上下文

`TraceParent` 包含 trace ID、发送方当前 span 的 ID 和 flags。这个 span 会成为接收方的父级。`TraceState` 保存有序的供应商条目。`SpanContext` 将这两个值与 `isRemote` 放在一起，用后者标识从其他进程提取的上下文。本地子 span 继承 trace ID、flags 和 state，生成新的 span ID，并将 `isRemote` 设为 `false`。

由网络层决定哪些目的地需要传递这些 header。对于需要向下游传播上下文的请求，在客户端 span 内调用下面的函数。

```swift
import Foundation

func attachTraceContext(to request: inout URLRequest) {
    guard let context = TraceScope.current else { return }
    request.setValue(context.traceParent.headerValue, forHTTPHeaderField: "traceparent")
    let state = context.traceState.headerValue
    request.setValue(state.isEmpty ? nil : state, forHTTPHeaderField: "tracestate")
}
```

接收方先读取 header、绑定远端父上下文，再开启 server span。下面的处理会在 parent 缺失或无效时从新根开始。只要 parent 有效，即使供应商状态缺失或无效，也可以继续同一条 trace。

```swift
func handleRequest(
    parentHeader: String?,
    stateHeader: String?,
    handle: () throws -> Void
) rethrows {
    let parent = parentHeader.flatMap(TraceParent.init(headerValue:)).map { traceParent in
        SpanContext(
            traceParent: traceParent,
            traceState: stateHeader.flatMap(TraceState.init(headerValue:)) ?? TraceState(),
            isRemote: true
        )
    }
    try TraceScope.$current.withValue(parent) {
        try withSpan("Handle order", ofKind: .server) { _ in try handle() }
    }
}
```

Telescopium 接受版本 `00` 的 55 字节小写格式，例如 `00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01`。trace ID 占 32 个十六进制字符，span ID 占 16 个，前导零会保留。任意一个 ID 全零、版本不支持或首尾有空白都会导致解析失败。最后一个字节完整保留 flags。内置 tracer 创建根时将 sampled 位清零，子 span 继承父级 flags。本地是否记录内容由 exporter 配置决定。[W3C Trace Context](https://www.w3.org/TR/trace-context/)

创建新身份可用 `TraceParent.random()`。测试需要可复现的数据时，可以给 `random(using:)` 传入 `SeededRandomNumberGenerator`，它使用 SplitMix64，同一种子会重现同一序列。`TraceParent`、`TraceId`、`SpanId` 和 `TraceState` 均编码为单个字符串。更新供应商状态时，`settingValue(_:forKey:)` 返回新值，并将更新的条目放到最前面，输入无效时返回 `nil`。在已有 32 个条目时新增 key 会淘汰最后一项。

## 在 Instruments 中查看耗时

在 App 启动处装饰 tracer，并在那里指定 subsystem 和 category。下面的配置同时导出 span 并记录 signpost。只接 Instruments 时可用 `TelescopiumTracer().signposted(by: signposter)`。

```swift
import os

let signposter = OSSignposter(
    subsystem: "com.example.shop",
    category: .pointsOfInterest
)
Trace.register(tracer: tracer.signposted(by: signposter))
```

用 Instruments 的 `os_signpost` 工具录制，在配置的 subsystem 和 category 下查找名为 `Span` 的区间。操作名会出现在公开的区间消息中，适合使用 `GET /orders/{id}` 这样的稳定名称。span 开始时 signposter 已启用才会生成区间。`SpanEvent` 仍然交给底层 span。App 需要单独标记时间点时，可以直接调用 `signposter.emitEvent("Checkpoint")`。
