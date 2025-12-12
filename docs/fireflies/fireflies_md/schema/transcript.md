# Transcript Schema - Fireflies.ai API Documentation

_Source_: https://docs.fireflies.ai/schema/transcript

[Skip to main content](#content-area)

[Fireflies home page![light logo](https://mintcdn.com/firefliesai/1yZ69Sj9FG7Gc0Ag/logo/light.svg?fit=max&auto=format&n=1yZ69Sj9FG7Gc0Ag&q=85&s=89d57b6f64984918e600fab4b327d867)![dark logo](https://mintcdn.com/firefliesai/1yZ69Sj9FG7Gc0Ag/logo/dark.svg?fit=max&auto=format&n=1yZ69Sj9FG7Gc0Ag&q=85&s=46855320026ba559f9e81763bda4d1eb)](https://fireflies.ai)

Search...

⌘K

Search...

Navigation

Schema

Transcript

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

- [Additional Resources](#additional-resources)

[​](#param-id)

id

ID

Unique identifier of the Transcript.

[​](#param-title)

title

String

Title of the Transcript.

[​](#param-host-email)

host\_email

String

[DEPRECATED](/additional-info/deprecated)   
Email address of the meeting host.

[​](#param-organizer-email)

organizer\_email

String

Email address of the meeting organizer.

[​](#param-user)

user

User

The [User](/schema/user) who Fred recorded the meeting on behalf of

[​](#param-speakers)

speakers

[Speaker]

The speakers array contains the id and name of the speaker as it appears within the transcript

[​](#param-transcript-url)

transcript\_url

String

The url to view the transcript in the dashboard

[​](#param-participants)

participants

[String]

An array of email addresses of meeting participants guests, including participants that do not
have Fireflies account.

[​](#param-meeting-attendees)

meeting\_attendees

[MeetingAttendee]

List of [MeetingAttendee](/schema/meeting-attendee)

[​](#param-meeting-attendance)

meeting\_attendance

[MeetingAttendance]

List of [MeetingAttendance](/schema/meeting-attendance) records showing when participants joined and left the meeting

[​](#param-fireflies-users)

fireflies\_users

[String]

An array of email addresses of only Fireflies users participants that have fireflies account that
participated in the meeting

[​](#param-duration)

duration

Number

Duration of the audio in minutes

[​](#param-date-string)

dateString

DateTime

String representation of DateTime. Example: `2024-04-22T20:14:04.454Z`

[​](#param-date)

date

Float

Date the transcript was created represented in milliseconds from
[EPOCH](https://en.wikipedia.org/wiki/Epoch_(computing)).The timezone for this field is UTC +00:00

[​](#param-audio-url)

audio\_url

String

Secure, newly generated hashed url that allows you download meeting audio. This url expires after
every 24 hours. You’d have to make another request to generate a new audio\_url.You need to be subscribed to subscribed to a pro or higher plan to query audio\_url. View plans [here](https://fireflies.ai/pricing)

[​](#param-video-url)

video\_url

String

Secure, newly generated hashed url that allows you download meeting video. This url expires after
every 24 hours. You’d have to make another request to generate a new video\_url. You will need to
enable `RECORD MEETING VIDEO` setting on your Fireflies
[dashboard](https://app.fireflies.ai/settings) for this to work.You need to be subscribed to a business or higher plan to query video\_url. View plans [here](https://fireflies.ai/pricing)

[​](#param-sentence)

sentence

[Sentence]

An array of [Sentence](/schema/sentence)(s), containing transcript details like `raw_text`,
`speaker_name`, etc.

[​](#param-calendar-id)

calendar\_id

String

Calendar provider event ID. This field represents calId for google calendar and iCalUID for
outlook calendar.

[​](#param-summary)

summary

Summary

AI generated [Summary](/schema/summary) of the meeting.

[​](#param-meeting-info)

meeting\_info

MeetingInfo

[MeetingInfo](/schema/meeting-info) metadata fields.

[​](#param-cal-id)

cal\_id

String

Calendar provider event ID with a timestamp that helps uniquely identify recurring events

[​](#param-calendar-type)

calendar\_type

String

Calendar provider name

[​](#param-apps)

apps

Apps

Preview of [Apps](/schema/apps) generated from the transcript. Max limit of 5 most recent AI App Outputs per meeting. Use the [Apps Query](/graphql-api/query/apps) to fetch the entire list of AI App Outputs

[​](#param-meeting-link)

meeting\_link

String

The web conferencing url of the meeting. This field is only populated if the meeting was hosted on a supported platform such as Google Meet, Zoom, etc.

[​](#param-analytics)

analytics

MeetingAnalytics

[MeetingAnalytics](/schema/meeting-analytics) contains analytics data about the meeting, including:

- `sentiments`: Sentiment analysis showing percentages of positive, neutral, and negative sentiments
- `categories`: Counts of different types of content (questions, date/times, metrics, tasks)
- `speakers`: Detailed analytics for each speaker including duration, word count, filler words, etc.

You need to be subscribed to subscribed to a pro or higher plan to query meeting analytics. View plans [here](https://fireflies.ai/pricing)

[​](#param-channels)

channels

[Channel]

An array of [Channel](/schema/channel) the meeting belongs to

## [​](#additional-resources) Additional Resources

[## Summary

Schema for Summary](/schema/summary)[## Sentence

Schema for Sentence](/schema/sentence)

Was this page helpful?

YesNo

[Suggest edits](https://github.com/firefliesai/public-api-ff/edit/master/docs/schema/transcript.mdx)[Raise issue](https://github.com/firefliesai/public-api-ff/issues/new?title=Issue on docs&body=Path: /schema/transcript)

[Speaker](/schema/speaker)[User](/schema/user)

⌘I