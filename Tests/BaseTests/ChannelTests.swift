import Testing

@testable import OmniusCoreBase

private actor Flag {
    private var value = false

    func setTrue() {
        value = true
    }

    func get() -> Bool {
        value
    }
}

@Test func unboundedReadWrite() async throws {
    let channel = Channel<Int>.createUnbounded()

    try await channel.writer.write(1)
    try await channel.writer.write(2)

    let first = try await channel.reader.read()
    let second = try await channel.reader.read()

    #expect(first == 1)
    #expect(second == 2)
}

@Test func completionWaitsForDrain() async throws {
    let channel = Channel<Int>.createUnbounded()
    try await channel.writer.write(10)
    await channel.writer.complete()

    let flag = Flag()
    let completionTask = Task {
        await channel.completion.value
        await flag.setTrue()
    }

    await Task.yield()
    #expect(await flag.get() == false)

    let value = try await channel.reader.read()
    #expect(value == 10)

    await completionTask.value
    #expect(await flag.get() == true)

    do {
        _ = try await channel.reader.read()
        #expect(Bool(false))
    } catch is ChannelClosedError {
        #expect(true)
    } catch {
        #expect(Bool(false))
    }

}

@Test func boundedWaitBlocks() async throws {
    let channel = Channel<Int>.createBounded(BoundedChannelOptions(capacity: 1, fullMode: .wait))

    try await channel.writer.write(1)

    let flag = Flag()
    let writerTask = Task {
        try await channel.writer.write(2)
        await flag.setTrue()
    }

    await Task.yield()
    #expect(await flag.get() == false)

    let first = try await channel.reader.read()
    #expect(first == 1)

    await Task.yield()
    #expect(await flag.get() == true)

    let second = try await channel.reader.read()
    #expect(second == 2)

    _ = try await writerTask.value
}

@Test func boundedDropOldest() async throws {
    let channel = Channel<Int>.createBounded(BoundedChannelOptions(capacity: 2, fullMode: .dropOldest))

    _ = await channel.writer.tryWrite(1)
    _ = await channel.writer.tryWrite(2)
    _ = await channel.writer.tryWrite(3)

    let first = try await channel.reader.read()
    let second = try await channel.reader.read()

    #expect(first == 2)
    #expect(second == 3)
}

@Test func boundedDropNewest() async throws {
    let channel = Channel<Int>.createBounded(BoundedChannelOptions(capacity: 2, fullMode: .dropNewest))

    _ = await channel.writer.tryWrite(1)
    _ = await channel.writer.tryWrite(2)
    _ = await channel.writer.tryWrite(3)

    let first = try await channel.reader.read()
    let second = try await channel.reader.read()

    #expect(first == 1)
    #expect(second == 3)
}

@Test func boundedDropWrite() async throws {
    let channel = Channel<Int>.createBounded(BoundedChannelOptions(capacity: 2, fullMode: .dropWrite))

    _ = await channel.writer.tryWrite(1)
    _ = await channel.writer.tryWrite(2)
    let accepted = await channel.writer.tryWrite(3)

    #expect(accepted == true)

    let first = try await channel.reader.read()
    let second = try await channel.reader.read()

    #expect(first == 1)
    #expect(second == 2)
}
