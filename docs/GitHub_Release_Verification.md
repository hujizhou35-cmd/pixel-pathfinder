# GitHub v2.0.0 release verification

Status: `PUBLISHED_AND_VERIFIED`

Verified on 2026-07-28 (Asia/Shanghai).

## Publication

- Repository: <https://github.com/hujizhou35-cmd/pixel-pathfinder>
- Visibility/default branch: public / `main`
- Release source commit: `776fe94e1ee41f964a02eaeb6c23dd31240fa2c8`
- Annotated tag: `v2.0.0`
- Tag object: `0c63f3aeff4e5d185289b4c5c0aef96bd5379885`
- Release: [Pixel Pathfinder v2.0.0](https://github.com/hujizhou35-cmd/pixel-pathfinder/releases/tag/v2.0.0)
- State: latest, published, not a draft, not a prerelease
- Published at: `2026-07-27T16:25:48Z`

## Release assets

| Asset | Bytes | GitHub SHA-256 digest |
| --- | ---: | --- |
| `PixelPathfinder_v2.0.0_Windows_x64.exe` | 163,884,672 | `2C637A575C07C54636FE898598F8CD553EBB7CB0EDDCD2F7607DA293E4CA527E` |
| `PixelPathfinder_v2.0.0_Windows_x64.zip` | 109,112,433 | `AB63E7BE141BDD5B14DE08038C9797115ED3C7227BD3CC305D055E61B8EDAEEA` |
| `SHA256SUMS.txt` | 212 | `1A4951D420953157D13354323B2CBB7CA4344242813E3A1D5E89FB983A6D5661` |

The public asset URLs accepted a fresh download request. The newly downloaded
`SHA256SUMS.txt` matched the local checksum file byte-for-byte. GitHub's
server-side digest for each uploaded asset exactly matched the corresponding
local release artifact. The large CDN transfer was not used as hash evidence:
the connection was stopped after download-start verification because the
observed route was limited to roughly 5 KB/s.

## Fresh tag clone

A clean `v2.0.0` clone resolved to the release commit above. The following
checks passed:

- Godot 4.3 first import generated a new class cache.
- The project launched headlessly and exited with code 0.
- The full smoke suite ended with `SMOKE OK - 全部检查通过`.
- `README.md`, its repository-relative screenshots, `LICENSE`, and test scenes
  were present.
- The clone did not depend on a machine-specific absolute project path.
