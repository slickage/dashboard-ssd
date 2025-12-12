# Analytics Schema - Fireflies.ai API Documentation

_Source_: https://docs.fireflies.ai/schema/analytics

[Skip to main content](#content-area)

[Fireflies home page![light logo](https://mintcdn.com/firefliesai/1yZ69Sj9FG7Gc0Ag/logo/light.svg?fit=max&auto=format&n=1yZ69Sj9FG7Gc0Ag&q=85&s=89d57b6f64984918e600fab4b327d867)![dark logo](https://mintcdn.com/firefliesai/1yZ69Sj9FG7Gc0Ag/logo/dark.svg?fit=max&auto=format&n=1yZ69Sj9FG7Gc0Ag&q=85&s=46855320026ba559f9e81763bda4d1eb)](https://fireflies.ai)

Search...

⌘K

Search...

Navigation

Schema

Analytics

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

- [TeamAnalytics](#teamanalytics)
- [TeamMeetingStats](#teammeetingstats)
- [UserMeetingStats](#usermeetingstats)
- [TeamConversationStats](#teamconversationstats)
- [UserConversationStats](#userconversationstats)
- [UserAnalytics](#useranalytics)
- [Additional Resources](#additional-resources)

[​](#param-team)

team

TeamAnalytics

Analytics data for the team. See [TeamAnalytics](#teamanalytics)

[​](#param-users)

users

[UserAnalytics]

List of analytics data for individual users. See [UserAnalytics](#useranalytics)

## [​](#teamanalytics) TeamAnalytics

[​](#param-conversation)

conversation

TeamConversationStats

Conversation statistics for the team. See [TeamConversationStats](#teamconversationstats)

[​](#param-meeting)

meeting

TeamMeetingStats

Meeting statistics for the team. See [TeamMeetingStats](#teammeetingstats)

## [​](#teammeetingstats) TeamMeetingStats

[​](#param-count)

count

Int

Total count of meetings

[​](#param-count-diff-pct)

count\_diff\_pct

Int

Percentage difference in meeting count compared to previous period

[​](#param-duration)

duration

Float

Total duration of meetings in minutes

[​](#param-duration-diff-pct)

duration\_diff\_pct

Int

Percentage difference in meeting duration compared to previous period

[​](#param-average-count)

average\_count

Int

Average number of meetings per user

[​](#param-average-count-diff-pct)

average\_count\_diff\_pct

Int

Percentage difference in average meeting count compared to previous period

[​](#param-average-duration)

average\_duration

Int

Average duration of meetings in minutes

[​](#param-average-duration-diff-pct)

average\_duration\_diff\_pct

Int

Percentage difference in average meeting duration compared to previous period

## [​](#usermeetingstats) UserMeetingStats

[​](#param-count-1)

count

Int

Total count of meetings for the user

[​](#param-count-diff)

count\_diff

Int

Difference in meeting count compared to previous period

[​](#param-count-diff-compared-to)

count\_diff\_compared\_to

Int

Meeting count in the previous period

[​](#param-count-diff-pct-1)

count\_diff\_pct

Int

Percentage difference in meeting count compared to previous period

[​](#param-duration-1)

duration

Float

Total duration of meetings in minutes for the user

[​](#param-duration-diff)

duration\_diff

Int

Difference in meeting duration compared to previous period

[​](#param-duration-diff-compared-to)

duration\_diff\_compared\_to

Int

Meeting duration in the previous period

[​](#param-duration-diff-pct-1)

duration\_diff\_pct

Int

Percentage difference in meeting duration compared to previous period

## [​](#teamconversationstats) TeamConversationStats

[​](#param-average-filler-words)

average\_filler\_words

Int

Average number of filler words used per meeting

[​](#param-average-filler-words-diff-pct)

average\_filler\_words\_diff\_pct

Int

Percentage difference in average filler words compared to previous period

[​](#param-average-monologues-count)

average\_monologues\_count

Int

Average number of monologues per meeting

[​](#param-average-monologues-count-diff-pct)

average\_monologues\_count\_diff\_pct

Int

Percentage difference in average monologues count compared to previous period

[​](#param-average-questions)

average\_questions

Int

Average number of questions asked per meeting

[​](#param-average-questions-diff-pct)

average\_questions\_diff\_pct

Int

Percentage difference in average questions compared to previous period

[​](#param-average-sentiments)

average\_sentiments

Sentiments

Average sentiment analysis results for team meetings. See [Sentiments](/schema/sentiments)

[​](#param-average-silence-duration)

average\_silence\_duration

Float

Average duration of silence in minutes per meeting

[​](#param-average-silence-duration-diff-pct)

average\_silence\_duration\_diff\_pct

Int

Percentage difference in average silence duration compared to previous period

[​](#param-average-talk-listen-ratio)

average\_talk\_listen\_ratio

Float

Average ratio of talking to listening across all meetings

[​](#param-average-words-per-minute)

average\_words\_per\_minute

Float

Average words spoken per minute across all meetings

[​](#param-longest-monologue-duration-sec)

longest\_monologue\_duration\_sec

Int

Duration in seconds of the longest monologue

[​](#param-longest-monologue-duration-diff-pct)

longest\_monologue\_duration\_diff\_pct

Int

Percentage difference in longest monologue duration compared to previous period

[​](#param-total-filler-words)

total\_filler\_words

Int

Total number of filler words used across all meetings

[​](#param-total-filler-words-diff-pct)

total\_filler\_words\_diff\_pct

Int

Percentage difference in total filler words compared to previous period

[​](#param-total-meeting-notes-count)

total\_meeting\_notes\_count

Int

Total count of meeting notes created

[​](#param-total-meetings-count)

total\_meetings\_count

Int

Total count of meetings

[​](#param-total-monologues-count)

total\_monologues\_count

Int

Total count of monologues across all meetings

[​](#param-total-monologues-diff-pct)

total\_monologues\_diff\_pct

Int

Percentage difference in total monologues compared to previous period

[​](#param-teammates-count)

teammates\_count

Int

Number of teammates included in the analytics

[​](#param-total-questions)

total\_questions

Int

Total number of questions asked across all meetings

[​](#param-total-questions-diff-pct)

total\_questions\_diff\_pct

Int

Percentage difference in total questions compared to previous period

[​](#param-total-silence-duration)

total\_silence\_duration

Float

Total duration of silence in minutes across all meetings

[​](#param-total-silence-duration-diff-pct)

total\_silence\_duration\_diff\_pct

Int

Percentage difference in total silence duration compared to previous period

## [​](#userconversationstats) UserConversationStats

[​](#param-talk-listen-pct)

talk\_listen\_pct

Float

Percentage of time spent talking vs listening

[​](#param-talk-listen-ratio)

talk\_listen\_ratio

Float

Ratio of talking to listening

[​](#param-total-silence-duration-1)

total\_silence\_duration

Float

Total duration of silence in minutes for the user

[​](#param-total-silence-duration-compare-to)

total\_silence\_duration\_compare\_to

Float

Silence duration in the previous period

[​](#param-total-silence-pct)

total\_silence\_pct

Float

Percentage of meeting time spent in silence

[​](#param-total-silence-ratio)

total\_silence\_ratio

Float

Ratio of silence to speaking time

[​](#param-total-speak-duration)

total\_speak\_duration

Float

Total duration of speaking time in minutes

[​](#param-total-speak-duration-with-user)

total\_speak\_duration\_with\_user

Float

Total duration of speaking time with specific user in minutes

[​](#param-total-word-count)

total\_word\_count

Int

Total count of words spoken

[​](#param-user-filler-words)

user\_filler\_words

Int

Number of filler words used by the user

[​](#param-user-filler-words-compare-to)

user\_filler\_words\_compare\_to

Int

Filler words used in the previous period

[​](#param-user-filler-words-diff-pct)

user\_filler\_words\_diff\_pct

Int

Percentage difference in filler words compared to previous period

[​](#param-user-longest-monologue-sec)

user\_longest\_monologue\_sec

Int

Duration in seconds of the user’s longest monologue

[​](#param-user-longest-monologue-compare-to)

user\_longest\_monologue\_compare\_to

Int

Longest monologue duration in the previous period

[​](#param-user-longest-monologue-diff-pct)

user\_longest\_monologue\_diff\_pct

Int

Percentage difference in longest monologue duration compared to previous period

[​](#param-user-monologues-count)

user\_monologues\_count

Int

Count of monologues by the user

[​](#param-user-monologues-count-compare-to)

user\_monologues\_count\_compare\_to

Int

Monologues count in the previous period

[​](#param-user-monologues-count-diff-pct)

user\_monologues\_count\_diff\_pct

Int

Percentage difference in monologues count compared to previous period

[​](#param-user-questions)

user\_questions

Int

Number of questions asked by the user

[​](#param-user-questions-compare-to)

user\_questions\_compare\_to

Int

Questions asked in the previous period

[​](#param-user-questions-diff-pct)

user\_questions\_diff\_pct

Int

Percentage difference in questions asked compared to previous period

[​](#param-user-speak-duration)

user\_speak\_duration

Float

Duration of time the user spent speaking in minutes

[​](#param-user-word-count)

user\_word\_count

Int

Count of words spoken by the user

[​](#param-user-words-per-minute)

user\_words\_per\_minute

Int

Words spoken per minute by the user

[​](#param-user-words-per-minute-compare-to)

user\_words\_per\_minute\_compare\_to

Int

Words per minute in the previous period

[​](#param-user-words-per-minute-diff-pct)

user\_words\_per\_minute\_diff\_pct

Int

Percentage difference in words per minute compared to previous period

## [​](#useranalytics) UserAnalytics

[​](#param-user-id)

user\_id

String

Unique identifier for the user

[​](#param-user-name)

user\_name

String

Name of the user

[​](#param-user-email)

user\_email

String

Email address of the user

[​](#param-conversation-1)

conversation

UserConversationStats

Conversation statistics for the user. See [UserConversationStats](#userconversationstats)

[​](#param-meeting-1)

meeting

UserMeetingStats

Meeting statistics for the user. See [UserMeetingStats](#usermeetingstats)

## [​](#additional-resources) Additional Resources

[## Sentiments

Schema for Sentiments](/schema/sentiments)[## Meeting Analytics

Schema for Meeting Analytics](/schema/meeting-analytics)

Was this page helpful?

YesNo

[Suggest edits](https://github.com/firefliesai/public-api-ff/edit/master/docs/schema/analytics.mdx)[Raise issue](https://github.com/firefliesai/public-api-ff/issues/new?title=Issue on docs&body=Path: /schema/analytics)

[AIFilter](/schema/aifilter)[AI Apps](/schema/apps)

⌘I