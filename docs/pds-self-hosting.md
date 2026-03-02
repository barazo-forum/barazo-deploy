# Self-Hosted PDS Reference Guide

A reference guide for running your own AT Protocol Personal Data Server (PDS) alongside Barazo. This is **not required** for most deployments -- it covers advanced use cases only.

## What is a PDS?

A Personal Data Server (PDS) is where AT Protocol user accounts and data live. When someone creates a post, replies to a topic, or updates their profile on Barazo, that data is written to their PDS. Barazo's AppView then indexes it from the firehose.

Think of it like email: the PDS is the mail server (stores your messages), while Barazo is the mail client (displays and organizes them).

**By default, Barazo users create accounts on Bluesky's free PDS (`bsky.social`).** This works out of the box with no additional infrastructure. Existing AT Protocol users (Bluesky, Blacksky, Northsky, or any compliant PDS) sign in via OAuth automatically.

## Do You Need a Self-Hosted PDS?

**Most community admins do not.** Barazo works with any AT Protocol-compliant PDS via standard OAuth. Users bring their own identity.

Self-hosting a PDS makes sense in specific scenarios:

| Use case | Why self-host |
|----------|--------------|
| **Data sovereignty** | Keep all user data on infrastructure you control |
| **Air-gapped environments** | Network-restricted deployments that cannot reach `bsky.social` |
| **Organizational accounts** | Issue AT Protocol identities under your own domain (e.g., `@jay.yourorg.com`) |
| **Regulatory compliance** | Data residency requirements that prohibit US-hosted PDS providers |

If none of these apply, use the default setup. Users sign up via Bluesky's PDS and it works.

## How Barazo Relates to a PDS

Understanding the data flow helps clarify why PDS hosting is separate from Barazo:

```
User's PDS (bsky.social or self-hosted)
  └── Stores user records (posts, replies, profiles)
        │
        ▼
AT Protocol Relay (bsky.network)
  └── Aggregates updates from all PDSs
        │
        ▼
Barazo AppView (your server)
  └── Indexes forum.barazo.* records
  └── Serves the forum UI
```

- **PDS** = source of truth for user data
- **Relay** = transport layer that broadcasts changes
- **AppView (Barazo)** = read index that presents the forum

Barazo never stores user content as the primary copy. If the AppView database is lost, it can be rebuilt from the firehose. If a user's PDS is lost, their data is gone (which is why PDS backup matters).

## Setting Up a Self-Hosted PDS

Barazo does not provide PDS software. The AT Protocol team maintains the official PDS implementation.

**Official documentation:** [atproto.com/guides/self-hosting](https://atproto.com/guides/self-hosting)

### Prerequisites

- A domain name (e.g., `pds.yourorg.com`)
- A server with a public IP address (separate from or co-located with your Barazo server)
- DNS records configured for your PDS domain
- SSL certificate (the official PDS installer handles this via Let's Encrypt)

### Key Steps (Summary)

The official installer script handles most of the setup. At a high level:

1. Point a DNS A record to your server
2. Run the official PDS installer script
3. Create user accounts on your PDS (via `pdsadmin`)
4. Users sign into Barazo using their PDS-hosted identity via OAuth

For detailed instructions, follow the official guide linked above. Do not rely on this summary -- the AT Protocol team updates their installer as the protocol evolves.

## Configuring Barazo for a Custom PDS

**No Barazo-specific configuration is needed.** AT Protocol OAuth handles PDS discovery automatically:

1. A user enters their handle (e.g., `@jay.yourorg.com`)
2. Barazo resolves the handle to a DID
3. The DID document points to the user's PDS
4. OAuth proceeds with that PDS

This works identically whether the user is on `bsky.social`, a third-party PDS, or your self-hosted PDS. The `RELAY_URL` in your Barazo `.env` controls which relay the AppView subscribes to for firehose events -- this is independent of where users' PDSs are hosted.

### Ensuring Your PDS Records Reach Barazo

For Barazo to index posts from your self-hosted PDS, the PDS must be connected to a relay that Barazo subscribes to. In the default configuration:

- Barazo subscribes to `wss://bsky.network` (the Bluesky relay)
- Your self-hosted PDS must be registered with this relay to have its records indexed

If your PDS is not connected to the Bluesky relay (e.g., air-gapped environments), you would need to run your own relay and point Barazo's `RELAY_URL` to it. This is an advanced configuration outside the scope of this guide.

## Limitations and Trade-offs

### Self-hosted PDS vs. bsky.social

| Aspect | bsky.social | Self-hosted PDS |
|--------|------------|-----------------|
| **Setup effort** | None (automatic) | Requires server, domain, DNS, maintenance |
| **Cost** | Free | Server costs + ongoing maintenance |
| **Data location** | US (Bluesky's infrastructure) | Your infrastructure, your jurisdiction |
| **Account recovery** | Bluesky handles it | You are responsible |
| **Uptime** | Managed by Bluesky team | Your responsibility |
| **Custom handles** | `*.bsky.social` or custom domain via DNS | Full control over handle namespace |
| **Relay connectivity** | Automatic | Must register with a relay |
| **Protocol updates** | Automatic | You manage PDS software updates |

### Important Considerations

- **Backup is your responsibility.** The PDS stores the authoritative copy of user data. If your PDS loses data, it cannot be recovered from Barazo (the AppView only holds an index).
- **PDS software updates** are released by the AT Protocol team. You must keep your PDS updated to remain compatible with the network.
- **Handle resolution** requires proper DNS configuration. If your DNS goes down, users cannot sign in.
- **One PDS per user.** A user's AT Protocol identity is tied to one PDS at a time. They can migrate between PDSs, but cannot use multiple simultaneously.

## Further Reading

- [AT Protocol Self-Hosting Guide](https://atproto.com/guides/self-hosting) -- official PDS setup instructions
- [AT Protocol Specification](https://atproto.com/specs) -- protocol details
- [Barazo Installation Guide](installation.md) -- setting up Barazo itself
- [Barazo Configuration Reference](configuration.md) -- all environment variables
