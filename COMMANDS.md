# Superskills Commands

## Maintenance

| Command | Description |
|---------|-------------|
| `/superskills-upgrade` | Upgrade superskills to the latest version — pulls from GitHub, re-runs setup, reports version change |

---

## Core Skills

### Dev Methodology

| Command | Description |
|---------|-------------|
| `/tdd` | Test-Driven Development — RED-GREEN-REFACTOR enforcement |
| `/debug` | Systematic debugging — 4-phase root cause analysis before proposing fixes |
| `/worktrees` | Creates isolated git worktrees for parallel feature development |
| `/finish-branch` | Guides branch cleanup and merge decisions when implementation is complete |
| `/verify` | Pre-merge validation — requires running verification commands and confirming output before success claims |
| `/write-plan` | Detailed implementation planning from a spec or requirements |

### Performance & Database

| Command | Description |
|---------|-------------|
| `/db-optimize` | Database performance audit — N+1 detection, EXPLAIN analysis, slow query log, join opportunities, per-endpoint DB call counts, missing index flags |
| `/perf-profile` | Application performance profiling — code execution time, DB call time, bottleneck identification across app and DB layers |
| `/cache-strategy` | Implement permanent cache-first strategy — check cache before DB, write on first read, invalidate only on data change (Play Framework model, no TTL) |

### Security

| Command | Description |
|---------|-------------|
| `/pentest` | Security scanning via clearwing (source code + network) |
| `/fuzz` | Web fuzzing via ffuf |
| `/defense` | Defense-in-depth — OWASP Top 10, secrets, auth, encryption |

### Spec Workflow

| Command | Description |
|---------|-------------|
| `/specify` | Create or update the feature specification from a natural language description |
| `/clarify` | Identify underspecified areas by asking up to 5 targeted clarification questions |
| `/analyze` | Cross-artifact consistency checking across spec.md, plan.md, and tasks.md |
| `/checklist` | Generate a custom quality checklist for the current feature |

### Startup

| Command | Description |
|---------|-------------|
| `/validate-idea` | Validate a business idea using the minimalist entrepreneur framework before building |
| `/pricing` | SaaS pricing strategy frameworks using minimalist entrepreneur principles |
| `/minimalist-review` | Review any business decision or plan through the minimalist entrepreneur lens |

### Knowledge & Content

| Command | Description |
|---------|-------------|
| `/tapestry` | Extract content from URLs and create action plans |
| `/youtube` | Download YouTube video transcripts from a URL |
| `/article` | Extract clean text from web articles and blog posts |
| `/kb-advisor` | Search and synthesize from connected knowledge bases |
| `/content-writer` | Content creation backed by knowledge base research |

### Testing

| Command | Description |
|---------|-------------|
| `/playwright` | E2E testing with Playwright |

### Codebase Context

| Command | Description |
|---------|-------------|
| `/repomap` | Generate a structural map of the codebase (REPOMAP.md) |
| `/dbmap` | Generate a database schema map (DBMAP.md) |
| `/repomap-auto-on` | Auto-update REPOMAP.md incrementally on every code change |
| `/repomap-auto-off` | Disable automatic repo map updates |
| `/graphify` | Turn any folder into a queryable knowledge graph — HTML, JSON, audit report |

---

## gstack (by Garry Tan)

> **Prerequisites:** `bun` v1.0+, Claude Code. Installed automatically by `./setup`.
> **Commands use a `gstack-` prefix by default** (e.g. `/gstack-review`, `/gstack-investigate`). Run `~/.claude/skills/gstack/setup --no-prefix` after install to use short names instead — but see overlap notes below before doing so.
> **Vendor copy:** `vendor/gstack/` in this repo backs up all skill definitions in case the upstream repo is removed.

### Planning & Strategy

| Command | Description | Overlaps with |
|---------|-------------|---------------|
| `/gstack-office-hours` | YC-style startup validation — six forcing questions that expose assumptions before writing any code | `/validate-idea` (similar intent; gstack is more aggressive/Socratic, superskills is framework-based) |
| `/gstack-plan-ceo-review` | Founder-mode plan review — rethinks the problem, finds the 10-star product | `/minimalist-review` (both challenge plans; gstack focuses on product scope, superskills on lean principles) |
| `/gstack-plan-eng-review` | Engineering architecture review — locks in data flow, testing strategy, and execution plan | `/write-plan` (both produce implementation plans; gstack is interactive review of an existing plan, superskills generates from scratch) |
| `/gstack-plan-design-review` | Designer's eye plan review — rates design dimensions 0–10 before implementation | `/design-audit` (design-skills) (audit vs. pre-implementation review) |
| `/gstack-plan-devex-review` | Developer experience plan review — evaluates DX personas and integration surfaces | — |
| `/gstack-autoplan` | Automated pipeline — runs CEO → design → eng → DX review chain with auto-decisions | `/analyze` (both check cross-artifact consistency; gstack runs full review chain, superskills checks spec/plan/tasks) |
| `/gstack-plan-tune` | Self-tuning question sensitivity for gstack reviews based on developer psychographic | — |

### Development & Review

| Command | Description | Overlaps with |
|---------|-------------|---------------|
| `/gstack-review` | Pre-landing PR review — checks SQL safety, LLM trust boundaries, rate limiting, and production readiness | `/verify` (**different focus**: gstack reviews the diff for security/correctness, superskills enforces running verification commands before declaring done — use both) |
| `/gstack-investigate` | Systematic root-cause debugging — four phases: investigate, hypothesize, test, confirm | `/debug` (**very similar**: both 4-phase systematic debugging. gstack uses browser for live investigation; superskills is code-only. **Prefer `/gstack-investigate` if browser access matters, `/debug` for pure code issues**) |
| `/gstack-health` | Code quality dashboard — runs type checker, linter, test suite, and scores 0–10 with trends | — |
| `/gstack-codex` | Cross-model code review — runs the same diff through Claude + OpenAI Codex independently | — |

### QA & Testing

| Command | Description | Overlaps with |
|---------|-------------|---------------|
| `/gstack-qa` | Browser-based QA — tests a web app with headless Chromium and auto-fixes bugs found | `/playwright` (**complementary**: playwright is test scripting; gstack-qa is exploratory QA with auto-fix) |
| `/gstack-qa-only` | Same as `/gstack-qa` but report-only — no automatic fixes | `/verify` (both report before declaring done; gstack-qa-only is browser-based, verify is command-output-based) |
| `/gstack-browse` | Fast headless Chromium control (~100ms/command) — navigate, click, screenshot, assert | — |
| `/gstack-open-gstack-browser` | Launch visible Chromium with the gstack sidebar extension for manual-style automated testing | — |
| `/gstack-setup-browser-cookies` | Import real browser cookies into the headless session for authenticated testing | — |
| `/gstack-benchmark` | Performance regression detection — establishes baselines and detects regressions | — |
| `/gstack-benchmark-models` | Cross-model benchmark — runs the same prompt through Claude, OpenAI, and others | — |

### Security

| Command | Description | Overlaps with |
|---------|-------------|---------------|
| `/gstack-cso` | Chief Security Officer mode — OWASP Top 10, STRIDE threat modeling, secrets archaeology | `/defense` (**very similar**: both cover OWASP Top 10 and secrets/auth. gstack-cso adds STRIDE threat modeling and is more systematic; `/defense` is a lighter checklist pass. **Prefer `/gstack-cso` for a deep audit, `/defense` for a quick review**) |
| `/gstack-careful` | Safety guardrails — warns before `rm -rf`, `DROP TABLE`, force-push, and other destructive commands | — |
| `/gstack-freeze` | Lock edits to a specific directory for the session — blocks `Edit` and `Write` outside the boundary | — |
| `/gstack-unfreeze` | Remove the freeze boundary set by `/gstack-freeze` | — |
| `/gstack-guard` | Combined safety mode: destructive command warnings + directory-scoped edits | — |

### Shipping & Deployment

| Command | Description | Overlaps with |
|---------|-------------|---------------|
| `/gstack-ship` | Full ship workflow — sync base branch, run tests, review diff, bump VERSION, create PR | `/finish-branch` (**similar end goal**: gstack-ship is automated and opinionated (VERSION bump, CI); finish-branch is interactive and guides the decision. **Use `/gstack-ship` when you want automation, `/finish-branch` when you want to think it through**) |
| `/gstack-land-and-deploy` | Merge PR, wait for CI, verify production | — |
| `/gstack-canary` | Post-deploy canary monitoring — watches live app for console errors and regressions | — |
| `/gstack-setup-deploy` | Configure deployment settings for `/gstack-land-and-deploy` | — |
| `/gstack-landing-report` | Read-only dashboard showing VERSION slots and ship queue status | — |
| `/gstack-gstack-upgrade` | Upgrade gstack to the latest version from upstream | — |

### Context & Memory

| Command | Description | Overlaps with |
|---------|-------------|---------------|
| `/gstack-context-save` | Save working context — captures git state, decisions made, remaining work | — |
| `/gstack-context-restore` | Restore a saved context from `/gstack-context-save` | — |
| `/gstack-setup-gbrain` | Set up gbrain — persistent knowledge base that survives session resets | — |
| `/gstack-learn` | Manage project learnings — review, search, prune, and export what gstack has stored | — |

### Codebase Context

| Command | Description | Overlaps with |
|---------|-------------|---------------|
| `/gstack-repomap` | Generate a repository structure map | `/repomap` (**exact duplicate in function** — if using `--no-prefix`, these will collide. superskills `/repomap` generates `REPOMAP.md`; gstack's version may format differently. **Keep prefix to avoid conflict**) |
| `/gstack-dbmap` | Generate a database schema map | `/dbmap` (**exact duplicate in function** — same collision risk as above. **Keep prefix**) |

### Multi-Agent & Collaboration

| Command | Description | Overlaps with |
|---------|-------------|---------------|
| `/gstack-pair-agent` | Coordinate a remote AI agent with shared browser access — generates a setup key | `/worktrees` (**different layer**: worktrees isolate code branches; pair-agent shares browser state between agents) |
| `/gstack-autoplan` | Automated multi-phase review pipeline (CEO → design → eng → DX) with auto-decisions | See Planning section above |

### Utilities

| Command | Description |
|---------|-------------|
| `/gstack-retro` | Weekly engineering retrospective — analyzes commit history and work patterns |
| `/gstack-devex-review` | Live developer experience audit using the browse tool to actually test the DX |
| `/gstack-document-release` | Post-ship doc update — reads all project docs and cross-references with the release |
| `/gstack-make-pdf` | Turn any markdown file into a publication-quality PDF with 1in margins |
| `/gstack-openclaw` | OpenClaw integration skills |

---

## Design Skills

| Command | Description |
|---------|-------------|
| `/adaptive-communication` | Adjust communication style based on whether the user is in relational or transactional mode |
| `/app-store-screenshots` | Generate App Store and Google Play marketing screenshots using Next.js |
| `/bencium-code-conventions` | Apply Bence's code style, tech stack, and workflow conventions |
| `/composition-patterns` | React composition patterns that scale — compound components, render props, context providers |
| `/deploy-to-vercel` | Deploy applications and websites to Vercel |
| `/design-audit` | Conduct systematic visual audits and produce phased, implementation-ready design plans |
| `/design-sprint` | Run a structured 5-day GV design sprint to prototype, test, and validate product ideas |
| `/design-taste-frontend` | Senior UI/UX engineering system enforcing metric-based design rules and CSS hardware acceleration |
| `/emil-design-eng` | UI polish, animation decisions, and invisible details that make software feel great (Emil Kowalski's philosophy) |
| `/full-output-enforcement` | Override LLM truncation behavior to enforce complete code generation |
| `/high-end-visual-design` | Design like a high-end agency with exact fonts, spacing, shadows, and animations |
| `/hooked-ux` | Design habit-forming product loops using the Hook Model (Trigger, Action, Variable Reward, Investment) |
| `/human-architect-mindset` | Systematic architectural thinking emphasizing irreplaceable human capabilities in system design |
| `/interface-design` | Interface design for dashboards, admin panels, and SaaS apps focused on craft and consistency |
| `/ios-dev` | iOS and Swift development covering SwiftUI, Human Interface Guidelines, accessibility, and app architecture |
| `/minimalist-ui` | Create clean editorial-style interfaces with warm monochrome palette and typographic contrast |
| `/negentropy-lens` | Evaluate systems through an entropy/negentropy lens — is this system decaying or growing? |
| `/organic-first-campaign` | Design grassroots-first campaigns for organizations facing spending disadvantages |
| `/react-best-practices` | React and Next.js performance optimization guidelines from Vercel Engineering |
| `/react-native-skills` | React Native and Expo best practices for building performant mobile apps |
| `/react-view-transitions` | Implement smooth animations using React's View Transition API |
| `/redesign-existing-projects` | Upgrade existing websites and apps to premium quality by auditing and applying high-end standards |
| `/relationship-design` | Design AI-first interfaces that build ongoing relationships through memory and trust evolution |
| `/renaissance-architecture` | Software architecture principles for building genuinely new solutions, not derivative work |
| `/swiftui-alarmkit` | Schedule alarms and countdown timers in iOS apps using AlarmKit (iOS 18+) |
| `/swiftui-charts-3d` | Create 3D data visualizations using Swift Charts (iOS/macOS 26+) |
| `/swiftui-text-editing` | SwiftUI text styling and rich text editing patterns with AttributedString |
| `/swiftui-toolbars` | Modern SwiftUI toolbar patterns including customizable toolbars and search integration |
| `/swiftui-webkit` | Embed and control web content in SwiftUI apps using WebView and WebPage (iOS/macOS 26+) |
| `/typography` | Apply professional typographic rules to screen-based UI |
| `/ui-refactor` | Tactical UI design guide for fixing layouts, selecting colors and fonts |
| `/ux-designer` | Expert UI/UX design collaboration — asks before making design decisions |
| `/ux-heuristics` | Evaluate and improve interface usability using heuristic analysis (Nielsen) |
| `/vercel-cli-with-tokens` | Deploy and manage Vercel projects using token-based authentication |
| `/web-design-guidelines` | Review UI code for Web Interface Guidelines compliance |

---

## Marketing Skills

### Analytics

| Command | Description |
|---------|-------------|
| `/google-search-console` | Analyze GSC data, use the Search Console API, or interpret search performance |
| `/seo-monitoring` | Build SEO data analysis systems and monitor indexing, traffic, keywords, and backlinks |
| `/ai-traffic` | Track AI search traffic (ChatGPT, Perplexity, Claude referrals) in GA4 or GSC |
| `/traffic` | Analyze website traffic sources, attribution, and dark traffic |
| `/tracking` | Set up, audit, or optimize analytics tracking (GA4, events, conversions) |

### Channels — Community & Distribution

| Command | Description |
|---------|-------------|
| `/community-forum` | Promote via forums and communities (Hacker News, Reddit, Discord, Quora) |
| `/directory-submission` | Submit a product to directories, curated lists, and launch platforms with ready-to-paste copy |
| `/product-hunt-launch` | Launch on Product Hunt — submission, hunter, first comment, timing, upvotes |
| `/distribution-channels` | Plan product distribution via marketplaces, app stores, and third-party platforms |

### Channels — Owned & Partnerships

| Command | Description |
|---------|-------------|
| `/email-marketing` | Plan email marketing, newsletters, and email deliverability (SPF, DKIM, DMARC) |
| `/employee-generated-content` | Plan and optimize employee-generated content and employee advocacy programs |
| `/affiliate-marketing` | Plan, implement, or optimize affiliate marketing strategy and commission structures |
| `/creator-program` | Plan and optimize creator program strategy and content co-creation |
| `/education-program` | Plan student and education discount programs |
| `/influencer-marketing` | Plan, implement, or optimize influencer and KOL marketing strategy |
| `/public-relations` | Plan PR, write press releases, and manage media relations |
| `/referral-program` | Plan, implement, or optimize referral programs and viral loops |

### Components — Branding

| Command | Description |
|---------|-------------|
| `/brand-visual` | Define, audit, or apply visual identity (typography, colors, design tokens) |
| `/favicon` | Implement, optimize, or audit favicon and app icons |
| `/hero` | Design, optimize, or audit hero sections (above-the-fold main visual area) |
| `/logo` | Optimize logo placement, linking, and branding on a website |

### Components — Content

| Command | Description |
|---------|-------------|
| `/comparison-table` | Create, optimize, or audit comparison table sections with feature matrices |
| `/howto-section` | Create, optimize, or audit HowTo sections with ordered steps and Schema.org JSON-LD |
| `/tab-accordion` | Add or optimize tab and accordion components for content organization |

### Components — Conversion

| Command | Description |
|---------|-------------|
| `/cta` | Design, optimize, or audit call-to-action buttons |
| `/newsletter-signup` | Design, optimize, or audit newsletter signup forms |
| `/popup` | Add, optimize, or audit popups and modals for lead capture |
| `/testimonials` | Add, optimize, or design customer testimonial and review sections |
| `/trust-badges` | Add or optimize trust badges, security seals, and social proof elements |

### Components — Layout

| Command | Description |
|---------|-------------|
| `/card` | Design, optimize, or audit card layouts for content display |
| `/carousel` | Design, optimize, or audit carousel/slider layouts |
| `/grid` | Design, optimize, or audit CSS grid layouts |
| `/list` | Design, optimize, or audit vertical list layouts |
| `/masonry` | Design, optimize, or audit masonry (Pinterest-style) layouts |

### Components — Navigation

| Command | Description |
|---------|-------------|
| `/breadcrumb` | Add, optimize, or audit breadcrumb navigation with BreadcrumbList schema |
| `/footer` | Design, optimize, or audit website footers |
| `/navigation-menu` | Design, optimize, or audit site navigation menus (navbar, mega menu, mobile menu) |
| `/sidebar` | Design, optimize, or audit sidebars for blogs, docs, or content pages |
| `/toc` | Add, optimize, or audit table of contents for long-form content |

### Components — Utility

| Command | Description |
|---------|-------------|
| `/social-share` | Add, optimize, or audit social share buttons (X, LinkedIn, Facebook) |
| `/top-banner` | Add, optimize, or audit top announcement bars and sticky banners |
| `/url-slug` | Create, optimize, or validate URL slugs for content pages |

### Content

| Command | Description |
|---------|-------------|
| `/article-content` | Write or generate article body content — blog posts, how-to guides, listicles |
| `/copywriting` | Write or optimize short-form marketing copy — headlines, CTAs, ad copy |
| `/podcast-marketing` | Plan, create, or market a podcast (strategy, SEO, show notes, distribution) |
| `/translation` | Translate content, manage terminology, and optimize translation quality |
| `/video-marketing` | Plan video marketing, create video scripts, and optimize short/long-form video |
| `/visual-content` | Plan, create, or repurpose visual content across channels |

### Pages — Brand

| Command | Description |
|---------|-------------|
| `/about-page-generator` | Create, optimize, or audit About page content |
| `/contact-page-generator` | Create, optimize, or audit contact pages and forms |
| `/homepage-generator` | Create, optimize, or audit the main site homepage |

### Pages — Content

| Command | Description |
|---------|-------------|
| `/api-page-generator` | Create, optimize, or audit the API introduction/overview page |
| `/article-page-generator` | Create, optimize, or audit a single article/post page |
| `/blog-page-generator` | Create, optimize, or audit blog index or listing page structure |
| `/docs-page-generator` | Create, optimize, or structure a documentation site |
| `/faq-page-generator` | Create, optimize, or audit FAQ page content with FAQ schema |
| `/features-page-generator` | Create, optimize, or audit features page content |
| `/glossary-page-generator` | Create, optimize, or audit glossary page content and structure |
| `/resources-page-generator` | Create, optimize, or audit resources pages and content hubs |
| `/template-page-generator` | Design template aggregation or detail pages for galleries and marketplaces |
| `/tools-page-generator` | Create, optimize, or audit free tools pages |

### Pages — Legal

| Command | Description |
|---------|-------------|
| `/cookie-policy-page-generator` | Create or optimize a cookie policy page |
| `/legal-page-generator` | Create, optimize, or structure legal pages (Privacy, Terms, etc.) |
| `/privacy-page-generator` | Create, optimize, or structure a Privacy Policy page |
| `/refund-page-generator` | Create or optimize a refund or return policy page |
| `/shipping-page-generator` | Create or optimize a shipping and delivery information page |
| `/terms-page-generator` | Create, optimize, or structure a Terms of Service page |

### Pages — Marketing

| Command | Description |
|---------|-------------|
| `/affiliate-page-generator` | Create, optimize, or audit affiliate program page content |
| `/alternatives-page-generator` | Create alternatives or competitor comparison pages and listicles |
| `/category-page-generator` | Create, optimize, or audit e-commerce category pages and listing pages |
| `/contest-page-generator` | Create, optimize, or audit giveaway and contest campaign pages |
| `/customer-stories-page-generator` | Create, optimize, or audit customer stories and case study pages |
| `/download-page-generator` | Create, optimize, or audit a download page for desktop or mobile apps |
| `/integrations-page-generator` | Create, optimize, or audit integrations, plugins, or extensions pages |
| `/landing-page-generator` | Create, optimize, or audit campaign landing pages for paid ads or email traffic |
| `/media-kit-page-generator` | Create, optimize, or audit media kit and press pages |
| `/migration-page-generator` | Create migration guides for users switching from competitors |
| `/press-coverage-page-generator` | Create an "As Seen In" press coverage or media mentions page |
| `/pricing-page-generator` | Create, optimize, or audit pricing page content and structure |
| `/products-page-generator` | Create, optimize, or audit a product listing or category page |
| `/services-page-generator` | Create, optimize, or audit a services page |
| `/showcase-page-generator` | Create, optimize, or audit a showcase or UGC gallery page |
| `/solutions-page-generator` | Create, optimize, or audit solutions pages by industry or company size |
| `/startups-page-generator` | Create, optimize, or audit a startups or special program page |
| `/use-cases-page-generator` | Create, optimize, or audit use case pages by persona or scenario |

### Pages — Utility

| Command | Description |
|---------|-------------|
| `/404-page-generator` | Create, optimize, or audit 404 error pages |
| `/careers-page-generator` | Create, optimize, or audit a careers and jobs page |
| `/changelog-page-generator` | Create, optimize, or structure a changelog or release notes page |
| `/disclosure-page-generator` | Create, optimize, or audit affiliate and sponsored content disclosure pages |
| `/feedback-page-generator` | Create, optimize, or audit a feedback or product roadmap page |
| `/signup-login-page-generator` | Create, optimize, or audit signup and login pages |
| `/status-page-generator` | Create, optimize, or structure a status and uptime page |

### Paid Ads — Formats

| Command | Description |
|---------|-------------|
| `/app-ads` | Run app install ads and user acquisition (UA) campaigns |
| `/ctv-ads` | Run CTV, OTT, or streaming TV ad campaigns |
| `/directory-listing-ads` | Run paid ads within directories and marketplaces (G2, Capterra, Taaft) |
| `/display-ads` | Run display, banner, or programmatic ad network campaigns |
| `/native-ads` | Run native ads on Taboola, Outbrain, or similar platforms |

### Paid Ads — Platforms

| Command | Description |
|---------|-------------|
| `/google-ads` | Set up, optimize, or manage Google Ads campaigns (Search, RSA, Performance Max) |
| `/linkedin-ads` | Set up, optimize, or manage LinkedIn Ads (Sponsored Content, Lead Gen Forms) |
| `/meta-ads` | Set up, optimize, or manage Meta (Facebook/Instagram) Ads |
| `/reddit-ads` | Set up, optimize, or manage Reddit Ads with subreddit targeting |
| `/tiktok-ads` | Set up, optimize, or manage TikTok Ads with Spark Ads and Events API |
| `/youtube-ads` | Run YouTube ad campaigns (TrueView, Bumper, Discovery) |

### Platforms

| Command | Description |
|---------|-------------|
| `/github` | Use GitHub for SEO, parasite SEO, GEO, open source marketing, and README optimization |
| `/grokipedia-recommendations` | Add recommendations, links, or content to Grokipedia for GEO/AI visibility |
| `/linkedin-posts` | Create LinkedIn post copy or optimize content for LinkedIn |
| `/medium-posts` | Write, publish, republish, or optimize posts on Medium.com |
| `/pinterest-posts` | Create Pinterest Pins, optimize descriptions, and grow Pinterest presence |
| `/reddit-posts` | Create Reddit post copy, comments, or optimize for subreddits |
| `/tiktok-captions` | Create TikTok video captions, scripts, or optimize for TikTok |
| `/twitter-x-posts` | Create X (Twitter) post copy, threads, or optimize for the X platform |
| `/youtube-seo` | Optimize YouTube videos for search — descriptions, tags, titles, thumbnails |

### SEO — Content SEO

| Command | Description |
|---------|-------------|
| `/competitor-research` | Analyze competitors for SEO, content, backlinks, and positioning |
| `/content-optimization` | Optimize content for SEO — word count, H2 keywords, density, multimedia, tables |
| `/content-strategy` | Plan content for SEO, create content calendars, and build topic clusters |
| `/eeat-signals` | Improve E-E-A-T — add trust signals, author bios, citations, and authority markers |
| `/keyword-research` | Research keywords, find target keywords, and analyze search intent |

### SEO — Entity & Local

| Command | Description |
|---------|-------------|
| `/entity-seo` | Optimize for entity recognition, Knowledge Graph, and entity-based SEO |
| `/local-seo` | Optimize for local search, Google Business Profile, and local citations |

### SEO — Off-Page

| Command | Description |
|---------|-------------|
| `/backlink-analysis` | Analyze backlinks, audit link profiles, and identify toxic links |
| `/link-building` | Build backlinks via outreach, guest posting, and broken link building |

### SEO — On-Page

| Command | Description |
|---------|-------------|
| `/meta-description` | Optimize the meta description for search snippets and CTR |
| `/featured-snippet` | Optimize for Featured Snippets and Position Zero |
| `/heading-structure` | Optimize heading hierarchy (H1–H6) and content structure |
| `/image-optimization` | Optimize images for SEO — alt text, WebP, lazy loading, srcset |
| `/internal-links` | Optimize internal linking, fix orphan pages, and improve link equity |
| `/page-metadata` | Optimize meta tags — hreflang, meta robots, viewport, charset |
| `/open-graph` | Add or optimize Open Graph metadata for social sharing previews |
| `/schema-markup` | Add or optimize structured data (Schema.org, JSON-LD, rich results) |
| `/serp-features` | Understand and optimize for SERP feature types (PAA, sitelinks, AI Overviews) |
| `/title-tag` | Optimize title tags for search — length, keyword placement, CTR |
| `/twitter-cards` | Add or optimize Twitter Card metadata for X link previews |
| `/url-structure` | Optimize URL structure, fix URL issues, and plan URL hierarchy |
| `/video-optimization` | Optimize videos for Google Search — video sitemap, VideoObject schema |

### SEO — Platform & Scale

| Command | Description |
|---------|-------------|
| `/parasite-seo` | Choose and execute third-party platform SEO on high-authority sites |
| `/programmatic-seo` | Create SEO pages at scale using templates and data |

### SEO — Technical

| Command | Description |
|---------|-------------|
| `/canonical-tag` | Configure canonical URLs, fix duplicate content, and consolidate URL signals |
| `/core-web-vitals` | Optimize Core Web Vitals — LCP, INP, CLS |
| `/site-crawlability` | Improve crawlability, fix orphan pages, and optimize site structure for bots |
| `/indexing` | Fix indexing issues from Search Console, use noindex, or implement Google Indexing API |
| `/indexnow` | Implement IndexNow to notify search engines of new/updated URLs instantly |
| `/mobile-friendly` | Optimize for mobile-first indexing and fix mobile usability issues |
| `/rendering-strategies` | Choose or optimize rendering strategy for SEO (SSR, SSG, CSR, ISR) |
| `/robots-txt` | Configure, audit, or optimize robots.txt and AI crawler rules |
| `/xml-sitemap` | Create, audit, or optimize sitemap.xml |

### Strategies — Brand

| Command | Description |
|---------|-------------|
| `/brand-monitoring` | Monitor brand mentions, detect trademark infringement, and set up brand watches |
| `/brand-protection` | Respond to brand impersonation, fake websites, phishing, and trademark infringement |
| `/branding` | Define, audit, or apply brand strategy — purpose, values, positioning, voice, narrative |
| `/content-marketing` | Plan content marketing across channels and create content repurposing strategies |
| `/integrated-marketing` | Plan integrated marketing and coordinate channels (IMC, PESO model) |
| `/rebranding-strategy` | Plan or execute a rebrand — domain change, 301 redirects, and brand announcement |

### Strategies — Commercial

| Command | Description |
|---------|-------------|
| `/domain-architecture` | Decide domain structure for multiple products — subfolder vs subdomain vs independent |
| `/domain-selection` | Choose an SEO-friendly domain — brand vs keyword domain, TLD selection |
| `/multi-domain-brand-seo` | Optimize brand search for companies with multiple domains |
| `/generative-engine-optimization` | Optimize for AI search visibility (ChatGPT, Claude, Perplexity, AI Overviews) |
| `/localization-strategy` | Plan localization strategy for multilingual and global growth |
| `/open-source-strategy` | Plan open source strategy, OSS commercialization, and open source growth |
| `/paid-ads-strategy` | Plan paid ads strategy, allocate ad budget, and choose paid channels |
| `/discount-marketing-strategy` | Plan discount and promotional pricing strategy (promo codes, LTDs, BFCM) |
| `/pricing-strategy` | Plan, design, or optimize pricing strategy and structure |

### Strategies — Launch

| Command | Description |
|---------|-------------|
| `/cold-start-strategy` | Plan cold start and get first users with zero traction |
| `/conversion-optimization` | Improve conversion rates, run A/B tests, and optimize funnels |
| `/growth-funnel` | Plan growth using the AARRR framework and diagnose growth bottlenecks |
| `/gtm-strategy` | Plan go-to-market strategy, GTM framework, and market entry |
| `/indie-hacker-strategy` | Indie hacker and bootstrapping founder strategy — Build in Public, solo founder tactics |
| `/pmf-strategy` | Validate product-market fit, measure PMF, and plan before scaling |
| `/product-launch` | Plan a product launch — channels, checklist, and announcement |
| `/research-sources` | Find information sources for content ideation and competitor monitoring |
| `/retention-strategy` | Reduce churn, improve customer retention, and plan lifecycle marketing |

### Strategies — Structure

| Command | Description |
|---------|-------------|
| `/seo-audit` | Run an SEO audit, technical SEO audit, or site health check |
| `/seo-strategy` | Plan SEO strategy, prioritize SEO work, and understand the SEO workflow |
| `/website-structure` | Plan website structure and decide which pages to build |
