---
title: Display versions and the commit an app runs
short_title: PLX-Releases
description: How an app repo's releases get a version people can read, MAJOR.MINOR as a git tag with a GitHub Release, and the two values every deployed app is handed to say what it is — its display version and the commit it was started from.
code: PLX-Releases
maturity: candidate
binds: repo
depends: [PLX-Delivery]
consumes: [PLX-App]
order: 18
---

An app release is an image keyed by a commit ([§ 3 PLX-Delivery](delivery.md)), which is all a deploy needs and nothing a person can say aloud.
This module gives an app repo a version for people, the **display version**, and tells every deployed app which commit it runs.
It binds app repos.
A package repo versions by changesets ([§ 5 PLX-Delivery](delivery.md)), and the operations repo releases nothing.

The page is a candidate, so it states no requirements yet.
Display versions are a question of the repo template, off unless a repo answers yes (§ 6); the commit is handed to every app repo's apps.


## § 1 The two values

A deploy hands an app two values, as environment variables under the reserved prefix ([§ 3 PLX-App](../contracts/app.md)).

| | `PLEXUS_DISPLAY_VERSION` | `PLEXUS_COMMIT_SHA` |
|---|---|---|
| Holds | a version, bare or with a `+`: `1.4`, `1.4+` | the full hash of a commit |
| Says | which version the deployment is, or which one it has left behind | which commit the deployment was started from |
| Handed to | the apps of a repo with display versions | the apps of every app repo |
| Where nothing hands it over | empty | empty |

The two are apart because they answer different questions.
A version names a state of production that people talk about; a commit names exactly what runs.
One string holding both would be a version in production and something else everywhere else, and two environments on the same commit would show different strings with nothing to tell that they match.

A display version carries no `v` and a commit is not shortened: putting a `v` in front and showing seven characters are presentation, and the app's own.
The term is "display version" throughout, to keep it apart from the Plexus version and from a package's version (§ 1.5 PLX).

Both values are pinned into the app's compose file by the deploy verb, in place of `${PLEXUS_DISPLAY_VERSION}` and `${PLEXUS_COMMIT_SHA}`, the way the image ref is ([§ 3 PLX-App](../contracts/app.md)).
An app reads them from its environment when it is asked, never at build time.
They are never built into the image: one image is built per content and deployed to every environment (§ 4 PLX-Delivery), and the same image shows `1.4+` on staging and `1.5` in production.


## § 2 Cutting a version

A version is `MAJOR.MINOR`, a git tag with no prefix, one line of versions per repo.
The tags are the only record.
Nothing writes a version into a `package.json` or any other file: a commit after every release would put `main` ahead of `develop` and break the fast-forward promotion (`PLX-Delivery/FastForwardPromotion`), and it would change the image it names.

Only a production release cuts a version, and only when it changes an app.
An app has changed when the image published under the released commit is not the image published under the last version's commit, compared by digest in the forge's registry.
A release that changes no image, a documentation change for instance, cuts nothing.
A hotfix is a production release like any other and takes the next minor.

The tag is made last, once every deploy of the release is green, together with a GitHub Release.
A version therefore names a state of production that happened, and a re-run of a failed deploy reaches the tag with the same number.
The release notes are the subjects of the commits since the previous version, merge commits left out, and the Release stays editable.

The release job of a repo with display versions runs one at a time per branch and is never cancelled, so that two pushes to `main` do not take the same number.


## § 3 What a deployment shows

The display version is read from the tags in the history of the released commit.

| The released commit | Display version |
|---|---|
| carries the tag of a version, or a production release cuts one with it | that version, `1.4` |
| deviates from the last version in its history | that version with a `+`, `1.4+` |
| has no version in its history | `0.0+` |

A `+` says that what runs is not a version: it is ahead of the one named.
Staging shows one almost always, since `develop` runs ahead of the last release.

Three cases follow from the rule and are meant.

**Staging keeps its `+` after a promotion.**
Staging is deployed before the tag exists, so it shows `1.4+` for the commit that production then releases as `1.5`, and it goes on showing `1.4+`: no release touches another environment.
The commit the two show is the same, and that is what says they match.
Staging shows `1.5+` once a later commit changes its image.

**Production can show a `+`.**
A production release that changes an app's compose file and no image cuts no version, and it restarts the app at a commit that carries no tag.
That app shows `1.5+` until the next version, which is true: production has left `1.5` behind and no version names where it is.

**An unchanged app keeps what it shows.**
In a repo of several apps, a release that changes one of them cuts a version for the repo, and the others are not restarted (§ 4).
They go on showing the version and the commit they were last started with.


## § 4 Neither value restarts an app

The deploy verb ends without pulling or restarting when the host already serves the app's image from the same compose file, healthy ([§ 6 PLX-Delivery](delivery.md)).
The two values change with every release, so the verb leaves them out of that comparison: a file that differs from the served one in the display version or the commit alone is the same deployment.
The host then keeps its file, and with it the values the app shows.

`PLEXUS_COMMIT_SHA` is therefore the commit a deployment was started from, not the newest commit released into its environment.
An app that a release leaves running was built from content that the newer commit did not change, so the commit it shows still names what runs.


## § 5 The major

The major is the repo's own decision, and it lives in the repo's marker (§ 1.4 PLX):

```markdown
---
major: 1
---
```

The minor counts up by itself.
A person raises `major` in the pull request that warrants it, and the next production release that cuts a version starts at `<major>.0`.
A major never goes back.
It is 1 or higher, so that `0.0+` only ever means that no version exists yet.

The release reads the marker on every run, in every environment.
A repo that turns display versions on without a usable `major` fails at its first push to `develop`, not at its first promotion.


## § 6 Taking it

Display versions are the answer `display_versions` of the app repo's template, and the default is no.
With it, the release job asks the release workflow for display versions, runs one at a time, and holds the permission to write the tag and the Release.
`major` is a question of the same template, asked when display versions are on: a number, 1 or higher, and 1 unless answered.
A repo born with the answer has `major: 1` in its marker, and a repo that turns the answer on later gets the same line from `plx apply` ([§ 3 PLX-Updates](updates.md)).

An app shows a value where its compose file uses the placeholder, and the app template's compose file names both.
A compose file without a placeholder ignores the value, so an app that shows nothing is deployed as before.

What an app does with the values is its interior.
In development nothing hands them over, both are empty, and the app decides what it shows then.
Nothing computes a version from git on a developer's machine: a checkout seldom has every tag, and a string that is often wrong is worse than none.


## Maintaining

`plx-ci display-versions` computes the display versions and the version a production release cuts, and `plx-ci tag-display-version` makes the tag and the Release; the header of their source in `tooling` states how both are read from the tags and the registry.
`plx deploy` pins the two values and leaves them out of its comparison ([PLX-CLI](cli.md)).
The reusable workflow `_release.yml` mounts them behind its input `display-versions` and hands the commit to every deploy.
The template `repo-turbo` asks the two questions and writes the release job; `app-nextjs` ships the two lines of the compose file.

The module shows what a release is and never decides one: what is built, published and deployed stays keyed by content and by commit ([§ 3 PLX-Delivery](delivery.md)).
A change that makes a deploy depend on a display version has left this module's fence.

The page becomes standard when two tenants' repos have display versions.
Its requirement then is the one act no template makes for a person, raising `major`.
