# PodSearch

_Search for podcasts!_

A re-implementation of [@_DavidSmith's Podcast Search](http://podcastsearch.david-smith.org/) tool, written in Elixir and calling out to Pocket Sphinx for transcription.

Very much a work-in-progress.

Aims are:
+ Give my computer something to do while I'm out
+ Automatic scraping of new episodes
+ Automatic backfill of unprocessed episodes
+ Full text search on transcripts
+ Error reporting on task failures
+ Task retries with some nice supervisors and stuff
+ Ability to run multiple transcription workers
+ Ad-hoc addition of new podcasts
+ Rate limiting transcription so I don't burn my computer
+ Progress reporting
