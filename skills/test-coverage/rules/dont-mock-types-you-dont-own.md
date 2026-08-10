# Never mock a type you don't own

Don't `mock(ThirdPartyClient)`. You don't control its contract, so the mock
silently drifts from real behavior as the library evolves — it'll keep
returning what you told it to long after the real API changed shape.

**Fix:**
- Use the library's own test double if it ships one (most SDKs do).
- Otherwise wrap the third-party API behind a thin interface **you** own
  (this is also SOLID-D from `ENGINEERING_STANDARDS.md`), then fake or mock
  *your* wrapper instead.

```
// Bad: mocks Stripe's SDK directly
const stripe = mock(StripeClient)
when(stripe.charges.create(any())).thenReturn({status: 'succeeded'})

// Better: wrap it, fake the wrapper
interface PaymentGateway { charge(amountCents: number): ChargeResult }
class StripeGateway implements PaymentGateway { /* real Stripe SDK calls */ }
class FakePaymentGateway implements PaymentGateway {
  charge(amountCents: number) { return { status: 'succeeded', amountCents } }
}
// test uses FakePaymentGateway — it can't drift from a contract you defined
```
