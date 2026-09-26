# Notes

A browser-based notes app built with [Gleam](https://gleam.run/),
[Lustre](https://hexdocs.pm/lustre/), and Tailwind CSS.

## Features

- Create and edit notes.
- Delete notes with confirmation.
- Keep notes between browser sessions with local storage.
- Inspect application history with the optional time-travel development entry
  point.

## Run locally

```sh
gleam run -m lustre/dev start
```

Then open the address printed by the development server.

## Run with time travel

The development-only entry point lives at `dev/notes_dev.gleam`, so it can use
`timetravel` without including the package in production builds.

```sh
gleam run -m lustre/dev start notes_dev
```

The development entry point adds a state-history inspector without changing the
normal application entry point.
