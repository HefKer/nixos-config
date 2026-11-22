# Upstream keeps its token, cache and queue beside the read-only script: the token comes from tokenPath (a sops secret), the rest moves to ~/.local/state/mpv/anilist-updater/.
{
  fetchFromGitHub,
  mpvScripts,
  python3,
  tokenPath,
}:
mpvScripts.buildLua {
  pname = "mpv-anilist-updater";
  version = "0-unstable-2026-11-18";
  src = fetchFromGitHub {
    owner = "AzuredBlue";
    repo = "mpv-anilist-updater";
    rev = "3190b4db04f67f446624bd16bf8b436daf02192a";
    hash = "sha256-WimJT+gr24KHoAh9PCWtSckeZUkfjnhYviM5jiTjzVA=";
  };
  scriptPath = ".";
  passthru.scriptName = "anilist-updater";

  postPatch = ''
    substituteInPlace anilist_updater/api.py \
      --replace-fail 'Path(__file__).resolve().parent.parent / "anilistToken.txt"' 'Path("${tokenPath}")'
    state='(Path.home() / ".local/state/mpv/anilist-updater")'
    substituteInPlace anilist_updater/cache.py \
      --replace-fail 'Path(__file__).resolve().parent.parent' "$state"
    # the state dir may not exist yet when the first cache or queue write happens
    substituteInPlace anilist_updater/cache.py \
      --replace-fail 'import tempfile  # ruff: ignore[import-outside-top-level]' \
        'import tempfile; path.parent.mkdir(parents=True, exist_ok=True)'
    substituteInPlace lua/backend.lua \
      --replace-fail '{ { "python3" } }' '{ { "${python3.interpreter}" } }'
    rm -rf .github installers tests
  '';

  meta.description = "Update AniList progress from the episode playing in mpv";
}
