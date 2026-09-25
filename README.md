# Notes

A browser-based notes app built with [Gleam](https://gleam.run/),
[Lustre](https://hexdocs.pm/lustre/), and Tailwind CSS.

## Run locally

```sh
gleam run -m lustre/dev start
```

Then open the address printed by the development server.

## Run with time travel

```sh
gleam run -m lustre/dev start notes_dev
```

The development entry point adds a state-history inspector without changing the
normal application entry point.

# lustre-app
