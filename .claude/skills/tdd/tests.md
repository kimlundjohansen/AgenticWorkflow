# Good and Bad Tests

## Good Tests

**Integration-style**: Test through real interfaces, not susbsitution of internal parts.

```csharp
// GOOD: Tests observable behavior
[Theory, AutoNSubstituteData]
public async Task PublishAsync_SendsMessage(
    [Frozen] IAzureClientFactory<ServiceBusClient> clientFactory,
    [Substitute] ServiceBusClient serviceBusClient,
    [Substitute] ServiceBusSender serviceBusSender,
    ServiceBusPublisher sut,
    string topic,
    string messageBody,
    CancellationToken cancellationToken)
{
    // Arrange
    clientFactory
        .CreateClient(Arg.Any<string>())
        .Returns(serviceBusClient);

    serviceBusClient
        .CreateSender(topic)
        .Returns(serviceBusSender);

    // Act
    await sut.PublishAsync(topic, messageBody, cancellationToken);

    // Assert
    var message = serviceBusSender.ReceivedCallWithArgument<ServiceBusMessage>();
    message.Body.ToString().Should().BeEquivalentTo(messageBody);
}
```

Characteristics:

- Tests behavior callers care about
- Uses public API only
- Survives internal refactors
- Describes WHAT, not HOW
- One logical assertion per test
- AutoFixture generates test data — no manual `new` or magic strings
- `[Frozen]` injects the same instance into the SUT and the test
- `[Substitute]` creates an NSubstitute substitute for types AutoFixture can't construct

## Bad Tests

**Implementation-detail tests**: Coupled to internal structure.

```csharp
// BAD: Tests HOW, not WHAT — verifies call count on an internal collaborator
[Theory, AutoNSubstituteData]
public async Task PublishAsync_CallsServiceBusSender(
    [Frozen] IInternalSenderWrapper senderWrapper,
    ServiceBusPublisher sut,
    string topic,
    CancellationToken cancellationToken)
{
    await sut.PublishAsync(topic, "body", cancellationToken);

    await senderWrapper.Received(1).SendInternalAsync(Arg.Any<object>(), cancellationToken);
}
```

Red flags:

- Substitute internal collaborators
- Testing private methods
- Asserting on call counts or invocation order as the primary assertion
- Test breaks when refactoring without behavior change
- Test name describes HOW not WHAT
- Verifying through external means instead of the public interface

```csharp
// BAD: Bypasses interface to verify
[Theory, AutoNSubstituteData]
public async Task CreateCustomer_SavesDocument(
    ICosmosWriter<CustomerDocument> writer,
    CreateCustomerCommand command,
    CancellationToken cancellationToken)
{
    await handler.HandleAsync(command, cancellationToken);

    await writer.Received(1).WriteAsync(Arg.Any<CustomerDocument>(), cancellationToken);
}

// GOOD: Verifies through the public interface
[Theory, AutoNSubstituteData]
public async Task CreateCustomer_MakesCustomerRetrievable(
    [Frozen] ICosmosReader<CustomerDocument> reader,
    CreateCustomerCommandHandler sut,
    CreateCustomerCommand command,
    CancellationToken cancellationToken)
{
    await sut.HandleAsync(command, cancellationToken);

    var result = await reader.ReadAsync(command.CustomerId, cancellationToken);
    result.Should().NotBeNull();
    result!.ExternalId.Should().Be(command.CustomerExternalId);
}
```
