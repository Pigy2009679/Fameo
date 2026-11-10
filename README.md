# FAMEO — Your Name. Your Fame.

FAMEO is a text-first social network concept.

- **Fans** = followers
- **Notes** = permanent text updates
- **Reactions** = likes
- **Replies** = comments

## Repository
- `index.html` — responsive front-end preview with Home, Notes, Popularity, Messages, Profile, and Settings.
- `supabase/schema.sql` — starter PostgreSQL schema and row-level security policies for a future Supabase backend.

## Run the preview
Open `index.html` in a browser or deploy the repository as a static site. Preview data is saved in the browser on that device only.

## Preview limitations
This is not yet a live multi-user social network. Sign-in, shared profiles, real Fans, cross-device Notes, messaging, and live leaderboards still need a backend connection.

## Backend setup
1. Create a Supabase project.
2. Run `supabase/schema.sql` in its SQL Editor.
3. Configure Supabase Auth.
4. Connect the app using the project URL and public anon key.
5. Implement and test authentication, profiles, Notes, reactions, replies, follows, message requests, blocks, reports, and moderation.

Never put a Supabase service-role key in browser code. The SQL is a starting point, not a production security review. Add server-side validation, rate limits, moderation, account deletion, privacy controls, and age-appropriate safety checks before launch.

The starter schema does not collect school, workplace, city, county, or precise location. Community leaderboards should be opt-in and must not expose private location or identity.
