# Slickage Dashboard

Web-accessible system for **monitoring** **client deployments**, communication with clients, contract management, and knowledge base, portfolio and case studies.

Julie
Ryan
Chris
Anthony
James

## Goals

* Make our contracting process as smooth as possible
  * Improve our effeciency and efficacy in communication
* **Streamline onboarding process**
* Improve transparency
* Improve internal business/tech advantages information secrecy
* Build **client confidence** by giving them (and us) some **peace of mind** with maintenance and longevity
  * Clients get some kind of support interface with the services they are paying for
  * Handoffs become easier \- we transfer monitoring and knowledge base to them
* Bring in **more revenue** by charging for maintenance, monitoring, support and upgrades
* Build **knowledge base**
  * public facing elements \- blog, documentation, etc. \- give us a better looking portfolio
* Scale the company so we can handle higher amount of employees
  * improve our morale and confidence
  * be able to **tackle bigger jobs**
  * **finish** more contracts
  * facilitate cooperation
  * improve organization
  * encourage specialization, ownership, and expertise
  * foster pride in the work that we do
* Show prospective clients and employees that this is a great place to work at
* Build accountability into the way that we work
* Visibility, Repeatability, Documentation, Structure
* Don't just jump straight into things, organize first
* Know when things are going to happen in advance

### Keep meeting on schedule and plan meeting out

"Slammed with meetings" for the whole morning
Agent uses the tech the same way as you would do

AI agent invited to meeting \- take notes and summarize
	Post text for agenda in chat
	Watch meeting, take notes, understand the agenda and ensure we're on topic
	Finish covering topics that were not finished
	Hook the AI agent into the project docs and have it keep track of that during meetings

Create an agent and invite to chat

Using AI in medical field \- see more patients

###

# Requirements Gathering Investigation/Interviews

Improve our ability to work together internally, and our ability to get great contracts, maintain a standard of quality in meeting the contract agreements, and get paid on time.

##

## Engineering

* Communication starts and ends in meetings
* It's hard to keep track of where things are going
  * Everyone's opinions may be different at the end of the meeting
  * Concensus is not always reached
  * *Eg: Is Slickage website is in rails or not?*
  * Direction from management can change randomly
* Workflow when lacking direction; showing is easier than explaining
  * Research technologies
  * Pick tools and make mock
* Use more industry standard tools/frameworks
  * Possibly better for our image if we use technologies that people know/have heard about
* Getting derailed during projects
  * This can happen internally or with clients
* Documents get lost
* Knowledge base
  * Drill down into certain parts of a project
  * Browse and find stuff
* Traditionally use **tickets** or **Board**
* Issues staying logged in to all tools and keeping them updated
* Take personal notes
* Board gets too big or tickets are too big \- feels overwhelming
* No estimates/difficult to estimate for current projects
  * Try to give estimates more often
  * Sprints?
* Everyone on a project needs access to communication/notes on/for client
  * Without this access, we could have blockers preventing progress
* What's it like to be onboarded into Slickage as an engineer?
  * Lacking formal onboarding process
    * Description of project and tools etc. would be helpful
    * See [epochtalk\_server Contributions doc](https://github.com/epochtalk/epochtalk_server/blob/main/CONTRIBUTIONS.md) for example
    * Or eg: [Remote](https://remotecom.notion.site/a3439c6ccaac4d5f8c7515c357345c11?v=8bb7f9be662f45da87ef4ab14a42be37) handbook
  * Clickup wasn't really being used
  * "Do your own work and talk about it during meetings"
  * Good that anybody who could help offered to do so \- very important
  * Low amount of egotism is a highlight of this company, we should keep this up
* Process in this document should improve organization, makes things a little more rigid and structured, but we should strive to keep it from becoming constricting
  * Sticking too strongly to rules and restrictions can also cause friction
  * But having no structure or too little structure makes things unclear and disorganized (waste time etc.)
* Style guide
  * Syntax
  * Semicolons
  * Linter
* Improve code quality
  * Do things the right way?
  * More focus on code review
  * More attention to detail
  * More communication
  * Design first and propose, then implement
  * Iteration
* Anthony's load is too much
* Simple interface \- Clickup is too complicated
  * Who's working on it
  * What are the tasks
  * Track what has been done
* **Project template guidelines**
* Help Chris gather requirements
* Employee reviews
* Code reviews

  ###

  ### Clients

* What is the lifecycle of a contract like (ideally)?
  * Through website
  * Schmoozing
  * Consulting
  * Negotiation
  * Establishing Scope of Work
  * Update meetings
  * Asynchronous communication:  Email/Text message/Slack etc.
* How do you find clients?
  * James does a couple of meet n greets
  * Referrals
    * How do we maximize potential for referrals and follow-on work?
    * (following sections discuss things we can do to maintain and improve client relationships)
* What's the process of turning a prospective client into a contract?
  * Julie, James, and Ryan
  * Form questions ahead of time based on James' notes
  * Iterations \- clients need time to think and decide
  * Some investigation \- gets built into the cost
* Written requirements (Scope of work)
  * We should host these documents for the client
    * Helps both parties if client is not as organized
  * Delivery timeline \- get better at sticking to it (linked in Clickup/dashboard)
    * Visible by client
  * List phases
  * Sent to client and decide yes or no
  * Sign contract
  * Agree to scope of work and re-negotiate if there's any changes
* Sticking to scope of work
  * Ryan is good at it
    * Asking good questions \- are they within scope of work?
    * With documents and agreements readily available, this will be easier
  * Follow up contracts
    * (Currently) Add new tasks to Clickup and then decide if they fit within current scope or should be added to a new scope
  * Tracker for tabled tasks
    * Keep visible to clients
* Many clients (esp small) are not so formal
  * Create a place for clients to view a summary of all of their interaction with us
  * Documents, scope of work, deliverables, schedule etc.
* Does an onboarding process help us? (James)
  * Customer engagement
    * Getting in contact with prospective clients
    * Communicating with existing clients
  * CRM \- perhaps too heavy for our needs
    * Summarize info exchanged in an intelligent way (Ryan)
    * Get this export to a single place
    * Possibly an application for AI
      * How do we make this secure?
    * Have this as part of the meeting process
      * possible to handle with AI too?
  * Client management
  * Engagement tracker?
  * Documentation
  * Correspondence
  * Email\!/Slack/phone call consolidation (Julie) \- Need to track communications across different medium, summarize notes
  * Would like a way to remember where things are \- and for which client
* Use case: New system \- add potential client
  * Define steps in process
  * Move to specific step
  * Predictively create document locations (Julie)
    * Define a template somewhere
  * Create Clickup list (Julie)
  * Make sure it's the same every time we sign up a new client (Julie)
  * Archive client (Julie)
    * Additionally, we could keep in touch with clients (Ryan)
    * Only truly "archive" a client if we're firing them (Ryan)
  * Maybe a checkbox list of what to generate? (Julie)
* Dashboard
  * Status of each project
  * Health of systems
    * Historical stats
    * Performance, tech stack, hardware info, etc.
  * Eg: Multiple contracts per client
  * Make documents and communication available to client
  * Project-related stats
    * Time frame in scope of work vs actual timeframe \- did we meet them?
    * Length of contract
    * Percent developer time?
    * Success
    * Clickup tasks opened vs completed
    * Time/money saved on client's side
      * Figure out what their system was like first (during discovery and in statement of work)
    * Summary of work completed
      * [Example (Epochtalk)](#case-study,-epochtalk)

  ### Discovery/Statement of work/Contracts

* "Our goal is to improve X service performance by Y"
  * Add this to dashboard info
  * Document this and we can use it later to tell new clients how much we helped previous clients
  * Hold us accountable
    * During project \- are we going to hit the goal?
    * Upon completion \- have we hit the goal?
* How do you write contracts?
  * Who writes them? \- Julie
    * Based on statement of work
    * What will we do?
    * How much will it cost?
  * What are key points that you make sure are well-defined?
  * How much/what kind of paperwork do you usually need for a contract and what's the process you do to handle it?
    * Mostly not much
    * Based on the amount of requirements the client has (example: Stanford)
* How is scope of work defined?
  * Try to gather the requirements as best as possible
  * Dependent on budget
  * Made in phases \- try not to exceed three months (1-2mo is best)
  * Checkpoints for scope
  * Allows for more change when phases are short \- more flexible
  * Continuous communication and improvement along the way
* Have you ever felt like there was a mistake written into a contract that caused issues in the work?
  * **Promise realistic goals**
    * need to know the capabilities of the team
    * *commission based on contract signing vs completion of project*
  * For technical customers, underlying technologies are important
  * Try to avoid emergency contracts \- relationship management
    * What is an emergency contract? \- A client asking for something that needs to be done within a couple of days
    * Stressful
      * Talk to Anthony
    * Possibly cause us to run late on other projects
    * Bill hourly \- must be beneficial to us
    * Relationship benefit (quantifiable)?
    * Start charging the mouse for cookies
  * **With a single place to view all projects \- Clickups, Dashboard, workloads, it will be easier to see the impact of an "emergency contract"/scope creep/changes to statement of work/last minute additions (Ryan)**
  * Balance relationships business and friendship
* What do we do in the case that a client breaks the contract agreement?
* What's the hardest part of our work with clients? \- what's holding us back from having a good flow in contracts? \- biggest pain points, prevents us from
  * Communication/Info exchange
    * Changing mind
    * Waffling \- flipping back and forth
      * "How about you order a krabby patty?"
    * "Happy path"
    * Want everything under the sun \- can be confused about what they want, and that's why they hire us
    * Want to mitigate before contract starts
  * Payment plans(?)
* How are state contracts different from private contracts?
  * Stall a lot and once you're done they say "that's not what I wanted"
  * They're not paying attention
* Are they worth the money and time?
  * **RFP** \- contract bidding system, always to lowest bidder
  * To combat nepotism
  * Good example of bad ideas
* How do we handle scope creep and other issues?
  * Delay/schedule for another phase
  * Why do we keep getting work that is outside of what we "agreed" on?
    * This wastes time
  * Why does the engineering team's tasks keep getting diverted (within a project)?
    * This wastes a lot of time
  * How do you think we could make that better?
    * Do our contracts have to be more specific?
  * What are other issues that we run into?
* We had issues with getting paid before, how did we remedy that?
  * Within contract agreements
  * Via client selection process
  * Not much you can do, but cut them off asap
* Do we have legal needs sometimes?
  * Eg: how to terminate contract
  * How are they handled and how could the process be better?
* Output static docs, link in dashboard

Ask Ryan about thought process when communicating between engineers and clients
Julie is there for feasibility checks

###

### Client communication

* How do we usually contact clients?
* What are the different ways we keep in contact, and how do we decide on how often and what type of communication we do?

### Pain points

* Lots of time in meetings
* (Perhaps) Lots of wasted time in meetings

### 	Possible solutions

### 	"Unsolvable" problems

* Are there any issues you consider to be unsolvable?

  ### Internal process

* What are some areas in which you think we could improve in terms of organization and workflow?
  * Dashboard
  * Service outage notifications
  * Updates

### Case study, EpochTalk {#case-study,-epochtalk}

* How was the EpochTalk contract designed to work, and what specific results did we agree to provide \- and on what timeline?
* **What did we learn from the EpochTalk contract?**
  * **What went right?**
  * **What went wrong?**
  * **Why did the project take so long?**
  * **Break down the issues into pieces and come up with solutions for each one**
  * **How can we fix our process to handle contracts better?**
* **Theymos didn't want to sit down and define things well**
  * Deliverables/milestones
  * **Compilation** of tasks promised and finished over time
  * What are we are going to do vs what we have done
    * What have we done in this time frame
    * What are we doing in the next time frame?
  * Have a list of Well defined accomplishments
  * Metrics \- what was it like before?
  * What is it like now?

### \!Actionable items

* Can we leverage a specific tool to make the contracting process easier?
* How can we ensure that the process fixes designated by this effort come to fruition?
* Should we create contract documents using AI?

# Contract managing software

[https://www.pcmag.com/picks/the-best-contract-management-software](https://www.pcmag.com/picks/the-best-contract-management-software)
[https://www.contractworks.com/](https://www.contractworks.com/)
[https://juro.com/learn/contract-management-software](https://juro.com/learn/contract-management-software)
[https://www.zoho.com/contracts/](https://www.zoho.com/contracts/)
[https://www.contracts365.com/](https://www.contracts365.com/)

* look through and see if there are any for small teams
* does/how does each software solve the problems that we face?
  * identify our pain points
  * match to a contract management software that solves those problems

![][image1]

###

# Info exchange

Let's improve our efficiency and efficacy in communication\!  Getting the right info from clients so that we can actually finish the work for them is a key step to success.  We need to do several things right in order to make sure there's good communication.

Key points:

* Have good meeting hygiene
* Maintain professional interaction
* Favor asynchronous communication
* Have a plan for handling issues/emergencies

Benefits:

* Free up meeting time \- as developers, we can do more engineering/coding/designing;  and as a CEO, there's more time to get organized, explore new contract opportunities, and build business connections
* Acheive smooth contract work flow
* Finish projects (need I say more?)
  * When we close contracts, we free up time and energy to work on new things
  * Having new clients keeps our skills sharp, and mitigates stagnation
* Build long lasting, trusting, and collaborative relationships with clients
  * If they are excited and happy to work with us, the work will be much easier
  * They will want to make the work go well and desire to help us help them

###

###

###

###

### Section Links

[Improve Client Communication](https://www.mural.co/blog/improve-client-communication)
[https://www.youtube.com/@501contractortips](https://www.youtube.com/@501contractortips)
[We're Friends Give Me A Good Price or Free Is Even Better – Contractor Business Tip \#353](https://www.youtube.com/watch?v=byzQyArabfk)
[Really "ME The Contractor" The Babysitter? – Contractor Business Tip \#354](https://www.youtube.com/watch?v=tNI0B_s40kE)

###

### Meeting hygiene

*Make sure meetings with clients accomplish our goal of getting the information we need from them\!  We want to be **aligned** and in **sync** with them so that we all understand and agree on what needs to be done and why.*

* Maintain professionalism
  * Don't use the meeting as time to socialize
  * …or for teams to argue internally
  * Don't offer services or agree to do work that is outside of the contract agreement
    * “That’s an interesting idea. We’ll discuss the details and whether or not it is in this scope of work”
  * Being professional maintains our integrity and protects us from clients' tendency to drag work out
  * Starting out professional and maintaining it will command the respect of the clients as business partners
* Maintain these standards for internal and external meetings
* **Show up to meetings \- not showing up is disrespectful to our client relationship**
  * Communicate in advance if you will not be there
* Start meetings "in the zone"
  * Generate meeting doc before meeting starts and integrate it into the meeting
    * Scheduler generates these resources and email it to everyone involved before meeting starts (something like this)
    * Dynamic doc (gdocs) \- link in dashboard
  * Prepare agenda (based on timeline)
    * Starter questions
    * Generate questions
    * Refine info
    * Go through new info
    * Needs to be tangible enough, but not too detailed
    * No open-ended contracts
  * Mentally prepare for meetings
  * Reserve some time (\~15 min) before the meeting to focus up
  * Review notes on the client and be prepared to handle reoccuring situations that cause inefficiency
* Respect time \- helps set professional boundaries
  * Time checks \- (15/10/5 mins remaining check)
    * Check time available against remaining items to discuss
    * Having agenda ready helps with this
  * Assertive on time
  * Respect their time
  * Respect our own time
  * Make sure they respect our time
  * Encourage them to respect their own time
  * Have less meetings if possible, and ensure that the few are worthwhile
* Respectful of opinions
  * Refrain from shutting people down or arguing your point without hearing others out and considering alternatives/compromise
  * If you notice this happening, involve others to help improve the situation
  * **Making communication public helps to de-escalate a debate**
  * Being a genius doesn't matter if you're an asshole
* Establish a communication schedule and stick to it
  * Ensure it is not more often than necessary
  * …and not too infrequent
  * Set a **reasonable** time limit for meetings
* Separate socializing time from business discussion time
  * We can be friends **outside** of work time
  * Project meetings should be a time to discuss project matters
* Make sure clients show up with the right info
  * Make sure they know what we need to know from them
    * Sending / sharing meeting agendas ahead of time
  * Use asynchronous methods (email, text, slack etc.)
* Make sure we show up with the right info
  * **prepare** before meetings
  * **document** all info for a client in one place and review before meetings
  * have a well-defined list of **talking points**
  * don't have too many talking points for the meeting length
  * understand what we need to know from them
  * ask pertinent questions
  * ask smart questions
  * ask for clarification
  * **reiterate** the information we recieved and get **confirmation**
  * add meeting notes back to the client's **document/contract info**
  * **follow up** with clients to ensure the work is being done as
* Triage meeting info
  * relay info within our team
  * add tasks to contract software/task manager
* Do not allow meetings to meander or run longer than planned \- cut them short if it's not productive
* Come up with a strategy to handle reoccuring issues
  * eg: if they often have internal arguments during meeting time that waste the meeting, take note of it and come up with a strategy to nip it in the bud next time
* Meeting checklist
  * Make sure everyone's got their checklist filled out

###

### Asynchronous (Non-meeting) Communication

Generate good documentation/knowledge base

When we architect a solution, it is good to be able to reference the design.
Before beginning implementation, let's ensure that there are diagrams and descriptions that we'll try to build our software to fit.

We can still work in an agile way, refactoring the design as new needs are discovered, but having

###

### Deployments \- test new tech

Allow devs to deploy things and view them through a portal in our internal site
Used to test out deployments and tech

Hook in

### List all projects

* included client info

### Client support tickets

* triage system [https://blog.invgate.com/ticket-triage](https://blog.invgate.com/ticket-triage)
* help client narrow down a topic \- what kind of issue is it?
  * severity
  * topic
* each type of topic is assigned to a subset of our team
  * each team member can handle certain types of tickets
  * get an email or slack notification when tickets come in
  * automatically add to **clickup** for that customer
* respond with cost estimate and lead time

### Deployment health checks

Drill down view into health checks for each of their deployments

* performance stats for deployed servers
  * uptime
  * percentage of hardware used
* AMI type
* memory/cpu/storage amounts and type
* tech stack
* CI/CD dashboard
  * build pass/fail
* github repos
* container build locations/versions

IT
Netdata \- free monitoring for linux based systems

* Web UI \- we can link to it from our site

[https://www.youtube.com/watch?v=Nr92b1eFRE0](https://www.youtube.com/watch?v=Nr92b1eFRE0)

Customer ticket triage
[https://blog.invgate.com/ticket-triage](https://blog.invgate.com/ticket-triage)

Server health monitoring
[https://www.solarwinds.com/server-application-monitor/use-cases/server-health-monitoring](https://www.solarwinds.com/server-application-monitor/use-cases/server-health-monitoring)

### Notification system

* security vulnerabilities
* failed builds
* down servers
* customer tickets
* performance limits
* reachability/network
* ai summary
  * scale suggestions
  * package upgrades
  * updated technology suggestions
  *

### Console commands

* authenticate
* add new customer/project
*

Auto-install health checker on each new deployment

### Knowledge base

Something to keep track of notes and diagrams
Integration with slickage.com

[Notion](https://www.notion.com/)

### stories

Customer has issue where site is down

* detected by health check system (ping or other)
* sends notification to responsible parties
  * log dump (from cloud logs or if machine(s) still online)
  * time of disrupted service
* notify client of service issue
* automatically attempt to restart machine(s) to restore service
  * create ticket if service does not revive
  * if service does revive, notify of resumed service

Server reaching performance limits

* detected by monitoring service
* send notification to responsible parties

Old work needs to be updated

* See dashboard for technology list
* See dashboard knowledge base for notes on implementation details

[image1]: <data:image/png;base64,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>
