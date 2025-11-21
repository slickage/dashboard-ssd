# MeetingAnalytics Schema - Fireflies.ai API Documentation

_Source_: https://docs.fireflies.ai/schema/meeting-analytics

[Skip to main content](#content-area)

[Fireflies home page![light logo](https://mintcdn.com/firefliesai/1yZ69Sj9FG7Gc0Ag/logo/light.svg?fit=max&auto=format&n=1yZ69Sj9FG7Gc0Ag&q=85&s=89d57b6f64984918e600fab4b327d867)![dark logo](https://mintcdn.com/firefliesai/1yZ69Sj9FG7Gc0Ag/logo/dark.svg?fit=max&auto=format&n=1yZ69Sj9FG7Gc0Ag&q=85&s=46855320026ba559f9e81763bda4d1eb)](https://fireflies.ai)

Search...

⌘K

Search...

Navigation

Schema

MeetingAnalytics

##### Getting Started

- [Introduction](/getting-started/introduction)
- [Quickstart](/getting-started/quickstart)
- [Chat with Fireflies AI Assistant](/getting-started/ask-docs)
- [Join the Developer Program](/getting-started/developer-program)
- [MCP Server Configuration](/getting-started/mcp-configuration)
- [LLM-based Development](/getting-started/llm-development)
- [What's New](/getting-started/whats-new)

##### Fundamentals

- [General concepts](/fundamentals/concepts)
- [Limits](/fundamentals/limits)
- [Errors](/fundamentals/errors)
- [Authorization](/fundamentals/authorization)
- [Introspection](/fundamentals/introspection)
- [Super Admin](/fundamentals/super-admin)

##### Examples

- [Overview](/examples/overview)
- [Basic](/examples/basic)
- [Advanced](/examples/advanced)

##### GraphQL API

- Query
- Mutation
- [Webhooks](/graphql-api/webhooks)

##### Realtime API

- [Overview](/realtime-api/overview)
- [Getting Started](/realtime-api/getting-started)
- [Event Schema](/realtime-api/event-schema)

##### Schema

- [ActiveMeeting](/schema/active-meeting)
- [AIFilter](/schema/aifilter)
- [Analytics](/schema/analytics)
- [AI Apps](/schema/apps)
- [App Output](/schema/app-output)
- [AudioUploadStatus](/schema/audio-upload-status)
- [Bite](/schema/bite)
- [Channel](/schema/channel)
- [MeetingAnalytics](/schema/meeting-analytics)
- [MeetingAttendee](/schema/meeting-attendee)
- [MeetingInfo](/schema/meeting-info)
- [Sentiments](/schema/sentiments)
- [Sentence](/schema/sentence)
- [Summary](/schema/summary)
- [SummarySection](/schema/summary-section)
- [Speaker](/schema/speaker)
- [Transcript](/schema/transcript)
- [User](/schema/user)
- [User Groups](/schema/user-groups)
- [User Group Member](/schema/user-group-member)
- Input

##### Miscellaneous

- [Language codes](/miscellaneous/language-codes)
- [Error codes](/miscellaneous/error-codes)

##### Additional Info

- [Deprecated](/additional-info/deprecated)
- [Changelog](/additional-info/change-log)

On this page

- [AnalyticsCategories](#analyticscategories)
- [AnalyticsSpeaker](#analyticsspeaker)
- [Additional Resources](#additional-resources)

[​](#param-sentiments)

sentiments

Sentiments

Sentiment analysis of the meeting. See [Sentiments](/schema/sentiments)

[​](#param-categories)

categories

AnalyticsCategories

Categorized analytics of the meeting content. See [AnalyticsCategories](#analyticscategories)

[​](#param-speakers)

speakers

[AnalyticsSpeaker]

Array of analytics data for each speaker in the meeting. See [AnalyticsSpeaker](#analyticsspeaker)

## [​](#analyticscategories) AnalyticsCategories

[​](#param-questions)

questions

Int

Number of questions asked during the meeting.

[​](#param-date-times)

date\_times

Int

Number of date and time references mentioned in the meeting.

[​](#param-metrics)

metrics

Int

Number of metrics or measurements discussed in the meeting.

[​](#param-tasks)

tasks

Int

Number of tasks or action items identified in the meeting.

## [​](#analyticsspeaker) AnalyticsSpeaker

[​](#param-speaker-id)

speaker\_id

Int

Unique identifier for the speaker.

[​](#param-name)

name

String

Name of the speaker.

[​](#param-duration)

duration

Float

Total speaking time of the speaker in seconds.

[​](#param-word-count)

word\_count

Int

Total number of words spoken by the speaker.

[​](#param-longest-monologue)

longest\_monologue

Float

Duration of the speaker’s longest continuous speech in seconds.

[​](#param-monologues-count)

monologues\_count

Int

Number of times the speaker spoke during the meeting.

[​](#param-filler-words)

filler\_words

Int

Number of filler words (um, uh, like, etc.) used by the speaker.

[​](#param-questions-1)

questions

Int

Number of questions asked by the speaker.

[​](#param-duration-pct)

duration\_pct

Float

Percentage of the total meeting time the speaker was talking.

[​](#param-words-per-minute)

words\_per\_minute

Float

Average speaking rate of the speaker in words per minute.

## [​](#additional-resources) Additional Resources

[## Sentiments

Schema for Sentiments](/schema/sentiments)[## Speaker

Schema for Speaker](/schema/speaker)

Was this page helpful?

YesNo

[Suggest edits](https://github.com/firefliesai/public-api-ff/edit/master/docs/schema/meeting-analytics.mdx)[Raise issue](https://github.com/firefliesai/public-api-ff/issues/new?title=Issue on docs&body=Path: /schema/meeting-analytics)

[Channel](/schema/channel)[MeetingAttendee](/schema/meeting-attendee)

⌘I