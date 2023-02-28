+++
title = "Rust Synchronous Executor"
[taxonomies]
categories = ["rust"]
+++

Someone asked for an executor that only executes synchronous code... So here's a terrible crime:

```rust
use std::future::Future;
use std::pin::Pin;
use std::task::Poll;
use std::task::{Context, RawWaker, RawWakerVTable, Waker};

fn fib(n: i32) -> Pin<Box<dyn Future<Output = i32>>> {
    if n <= 2 {
        Box::pin(async move {
            1
        })
    } else {
        Box::pin(async move {
            fib(n-1).await + fib(n-2).await
        })
    }
}

unsafe fn clone(_waker: *const ()) -> RawWaker {
    todo!()
}

unsafe fn wake(_waker: *const ()) {
    todo!()
}

unsafe fn wake_by_ref(_waker: *const ()) {
    todo!()
}

unsafe fn drop(_waker: *const ()) {
    
}

const VTABLE: RawWakerVTable = RawWakerVTable::new(clone, wake, wake_by_ref, drop);

fn block_on<F: Future>(mut fut: F) -> F::Output {
    let data = ();
    let raw_waker = RawWaker::new(&data as *const _, &VTABLE);
    let waker = unsafe { Waker::from_raw(raw_waker) };
    let mut ctx = Context::from_waker(&waker);
    loop {
        match unsafe { Pin::new_unchecked(&mut fut) }.poll(&mut ctx) {
            Poll::Ready(x) => {
                return x;
            }
            Poll::Pending => {}
        }
    }
}

fn main() {
    println!("fib: {}", block_on(fib(6)));
}
```

[Playground](https://play.rust-lang.org/?version=stable&mode=debug&edition=2021&gist=6da92b3be35f15532aee3b7aed3bb771)

It seems to work fine for some simple futures, but would of course crash on anything that wanted to do I/O.
