+++
title = "Desugaring async functions in Rust"
[taxonomies]
categories = ["rust"]
+++

[Here](https://github.com/ambiso/future_without_async) I implemented two simple futures without using `async fn`.

## A simple async function

We first look at the simplest possible example:

```rust
async fn does_nothing() {}
```

An `async` function boils down to a function returning some type that implements the [`Future`](https://doc.rust-lang.org/std/future/trait.Future.html#) trait:


```rust
fn does_nothing_desugared() -> impl Future<Output=()> {
    /* ... */
}
```

The `Future` trait looks like this:

```rust
pub trait Future {
    type Output;
    fn poll(self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Self::Output>;
}
```

It offers a poll function that an async runtime can call to make progress on the future.
We can implement this poll function by creating a struct that implements `Future`:

```rust
struct DoesNothingFuture;

impl Future for DoesNothingFuture {
    type Output = ();

    fn poll(self: Pin<&mut Self>, _cx: &mut Context<'_>) -> Poll<Self::Output> {
        Poll::Ready(())
    }
}
```

Here the `poll` function immediately resolves the future to the empty tuple.
The alternative would be to return `Poll::Pending` to signal that it should be 
polled again later. To determine when it should be polled again 
Rust futures have a [wakeup mechanism](https://rust-lang.github.io/async-book/02_execution/03_wakeups.html), which I won't detail here.

The `does_nothing_desugared` function then just has to return a new instance 
of the DoesNothingFuture:

```rust
fn does_nothing_desugared() -> impl Future<Output=()> {
    DoesNothingFuture {}
}
```

## A more complex example

Now lets try desugaring a more complex async function.

```rust
async fn read_file(file: &mut File) -> String {
    let mut v = Vec::new();
    file.read_to_end(&mut v).await.unwrap();
    String::from_utf8(v).unwrap()
}
```

The `read_file` function is more complex in that it has an argument and awaits another future.
To translate this function we again need a struct that implements `Future`:

```rust
struct ReadFileFuture<'a> {
    file: &'a mut File,
    v: Option<Vec<u8>>, // buffer to store data to
    state: ReadFileState<'a>,
    _pin: PhantomPinned, // Future is !Unpin
}

enum ReadFileState<'a> {
    State0, // Initial
    State1(Pin<Box<dyn Future<Output=tokio::io::Result<usize>>+'a>>), // Await ReadToEnd future
}
```

Here we take the reference to the file, a buffer to store the file contents to 
and a state that contains nothing initially, but is then filled by 
the `ReadToEnd` future when the `ReadFileFuture` is first polled.
We explicitly mark the future as `!Unpin` to avoid it being moved.
This is necessary since the `ReadToEnd` future holds references to `v` and to `file`.
Internally we need to use `unsafe` to circumvent the restrictions of `!Unpin`.
Here we must be careful not to move any members that another may hold references to.

The `poll` implementation checks which state we are in.
This roughly corresponds to the different entrypoints of the function:

- the main entrypoint of the function
- points where `.await` is used in the function

```rust
impl<'a> Future for ReadFileFuture<'a> {
    type Output = String;

    fn poll<'b>(mut self: Pin<&'b mut Self>, cx: &mut Context<'_>) -> Poll<Self::Output> {
        let s = unsafe { self.as_mut().get_unchecked_mut() };
        loop {
            match s.state {
                // Main entrypoint
                ReadFileState::State0 => {
                    let fut = s.file.read_to_end(s.v.as_mut().unwrap());
                    let wrapped = Box::pin(fut);
                    let new_state = unsafe { std::mem::transmute::<_, ReadFileState<'a>>(ReadFileState::State1(wrapped)) };
                    s.state = new_state;
                },
                // Await ReadToEnd
                ReadFileState::State1(ref mut fut) => {
                    let r = fut.as_mut().poll(cx);
                    if r.is_pending() {
                        return Poll::Pending;
                    }
                    let v = s.v.take().unwrap();
                    return Poll::Ready(String::from_utf8(v).unwrap());
                },
            }
        }
    }
}
```

We can then again simply return an instance of the struct in the desugared function:

```rust
fn read_file_desugared(file: &mut File) -> impl Future<Output=String> + '_ {
    ReadFileFuture {
        file,
        v: Some(Vec::new()),
        state: ReadFileState::State0,
        _pin: PhantomPinned {},
    }
}
```

I am not 100% sure my use of `unsafe` is sound here, in fact I would be surprised by it.
However, the application does run and seems to produce the correct result.

The transmute is used to convince the compiler to accept a different lifetime for `ReadFileState`.
This would likely not be necessary if Rust had support for self-referencing structs.

## Acknowledgement

- [Jon Gjengset: The What and How of Futures and async/await in Rust](https://www.youtube.com/watch?v=9_3krAQtD2k)
- [Jon Gjengset: The Why, What, and How of Pinning in Rust](https://www.youtube.com/watch?v=DkMwYxfSYNQ)
- [Yandros](https://users.rust-lang.org/t/desugaring-async-fn/63698/2)