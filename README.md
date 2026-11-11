# ambiso's blog

GitHub Pages builds this Zola site with the `ambiso.github.io` base URL from
`config.toml`. `nix build` uses the same source and theme but sets the base URL
to `https://robinleander.eu`, producing the version served by NixOS. The latter
has its own `robots.txt` and sitemap with `robinleander.eu` URLs.

`direnv allow` loads the flake development shell with the same Zola version as
the Nix build. The old theme uses Tera macros, so Zola is pinned to 0.22.1.
