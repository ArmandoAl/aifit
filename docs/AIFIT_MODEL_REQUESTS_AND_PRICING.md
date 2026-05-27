# AIFit — Model Requests, Cost Formulas, and Subscription Packaging

This document enumerates **every** AI model request AIFit performs today (per feature/flow), and provides a **cost modeling template** you can paste into Gemini to compute $/user and derive subscription pricing.

> Notes
> - This is **not** a redesign. It reflects the current implementation.
> - Costs depend on current provider pricing. Use the prompt in the last section to fill in live numbers.

---

## 1) Models used (current code)

### Conversational layer (stylist chat)
- **OpenAI**: `gpt-4.1-mini`
  - File: `lib/features/stylist/services/stylist_chat_service.dart`
  - Purpose: conversation + accumulate structured `StylistIntentState` JSON.

### Intent extraction (outfit pipeline)
- **DeepSeek**: `deepseek-chat` (OpenAI-compatible JSON mode)
  - File: `lib/core/services/deepseek_service.dart`, called by `lib/features/outfit/services/outfit_intent_analyzer.dart`
  - Purpose: generate structured `OutfitIntent` JSON from user prompt.
  - Optimization present: **skipped** when stylist chat already provides structured intent (chat path only).

### Wardrobe image analysis (metadata)
- **Gemini**: `gemini-2.5-flash` (JSON)
  - File: `lib/core/services/firebase_ai_service_impl.dart`
  - Purpose: analyze a wardrobe item image to JSON metadata (colors, tags, etc.).

### Outfit generation (multimodal selection)
- **Gemini**: `gemini-2.5-flash` (multimodal → JSON)
  - File: `lib/features/outfit/services/outfit_generator_service.dart`
  - Purpose: generate 3 outfits from garment images + wardrobe context.

### Identity analysis (profile JSON)
- **Gemini**: `gemini-2.5-pro` (JSON)
  - File: `lib/core/services/firebase_ai_service_impl.dart`, used by `lib/features/profile/services/user_identity_analysis_service.dart`
  - Purpose: produce `IdentityProfile` JSON from identity collage.

### Base image generation (one-time)
- **Gemini Image**: `gemini-2.5-flash-image`
  - File: `lib/features/outfit/services/user_base_image_service.dart`
  - Purpose: generate a reusable identity-locked base template.

### Try-on generation (per outfit)
- **Gemini Image**: `gemini-2.5-flash-image`
  - File: `lib/features/outfit/services/virtual_try_on_service.dart`
  - Purpose: generate final try-on image from base identity + face anchor + garments.

---

## 2) Requests per user flow (what calls happen and when)

### Flow A — Stylist chat session (no generation yet)
**Per user message:**
- 1× `gpt-4.1-mini` chat completion (JSON response)

**Variables**
- \(M\): number of user messages in a chat session until `readyToGenerate=true`

**Requests**
- OpenAI calls = \(M\)

---

### Flow B — Outfit suggestions (phases 1–3)
Triggered from chat CTA or Generate Outfit page.

**Always:**
- 1× Firestore query: `wardrobe_items where userId==uid`
- \(N_d\) garment image downloads (HTTP) where \(N_d \le 12\) today
- 1× `gemini-2.5-flash` multimodal request (images + prompt → JSON)
- 1× Firestore batch write: `saved_outfits` (async)

**Sometimes:**
- 1× DeepSeek `deepseek-chat` JSON intent extraction
  - **Skipped** in chat path when structured intent exists.

**Variables**
- \(N_d\): number of garment images successfully downloaded (0–12)
- \(I\): intent source indicator
  - \(I=1\) if DeepSeek called
  - \(I=0\) if skipped (chat provided `precomputedIntent`)

**Requests**
- DeepSeek calls = \(I\)
- Gemini Flash calls = 1

---

### Flow C — Try-on for an outfit (phase 4)
Triggered automatically for the first look (if enabled), or on-demand per outfit.

**Always:**
- 1× `gemini-2.5-flash-image` request (identity-locked try-on)
- 1× Storage upload of output image + Firestore update of `tryOnImageUrl` (async)

**Inputs sent to the model (typical):**
- 1× identity base image (from `baseImageUrl`) **if available**
- 1× face anchor image (first `facePhotos` URL) **if available**
- 3–4 garment images (tops/bottoms/shoes/outerwear) depending on outfit
- IdentityProfile JSON is embedded in the prompt text

**Variables**
- \(T\): number of try-ons user triggers in a session (0–3 typically)
- \(G_t\): garments per try-on (3–4)

**Requests**
- Gemini Flash Image calls = \(T\)

---

### Flow D — First-time onboarding identity pipeline (one-time per user, then cached)
Triggered when generating base image and identity profile is missing/stale.

**Sometimes (cold start):**
- 1× identity collage generation (local)
- 1× Storage upload of identity collage
- 1× `gemini-2.5-pro` JSON identity analysis
- 1× Firestore write of `identityProfile`, `identityCollageUrl`

**Then:**
- 1× `gemini-2.5-flash-image` base image generation
- 1× Storage upload base image + Firestore write `baseImageUrl`

**Variables**
- \(U\): number of users who complete onboarding in the billing period

**Requests**
- Gemini Pro calls (identity JSON) = \(U\) (once per user, when needed)
- Gemini Flash Image calls (base) = \(U\) (once per user, when needed)

---

### Flow E — Wardrobe item ingest (metadata per item)
Triggered per wardrobe item added or re-analyzed.

**Per wardrobe item:**
- 1× Storage upload original photo
- 1× `gemini-2.5-flash` JSON analysis (colors/style or full analysis)
- 1× Firestore write wardrobe item metadata

**Variables**
- \(W\): number of wardrobe items added per user per month

**Requests**
- Gemini Flash (JSON) calls = \(W\)

---

## 3) Cost modeling formulas (provider-agnostic)

Define these unit costs from current pricing (fill them in later):

- **OpenAI**:
  - \(C_{oa\_msg}\): cost per stylist message (avg tokens in/out)
- **DeepSeek**:
  - \(C_{ds}\): cost per intent extraction call
- **Gemini Flash**:
  - \(C_{gf\_mm}(N)\): cost per multimodal outfit generation with \(N\) images
  - \(C_{gf\_json}\): cost per wardrobe-item JSON analysis
- **Gemini Pro**:
  - \(C_{gp\_id}\): cost per identity JSON analysis (collage)
- **Gemini Flash Image**:
  - \(C_{gi\_base}\): cost per base image generation
  - \(C_{gi\_try}\): cost per try-on image generation

### Monthly cost per active user (template)

Let:
- \(M\) = chat messages/user/month
- \(O\) = outfit generations/user/month (phases 1–3)
- \(I\) = fraction of those generations that call DeepSeek (0–1)
- \(N\) = avg garment images sent to Gemini Flash per generation (<=12 today)
- \(T\) = try-ons/user/month
- \(W\) = wardrobe items added/user/month
- \(p_{new}\) = fraction of users who newly onboard this month (0–1)

Then:

\[
C_{user} =
M \cdot C_{oa\_msg}
 + O \cdot (I \cdot C_{ds} + C_{gf\_mm}(N))
 + T \cdot C_{gi\_try}
 + W \cdot C_{gf\_json}
 + p_{new} \cdot (C_{gp\_id} + C_{gi\_base})
\]

Add infra (optional):
- Storage bandwidth + egress (images)
- Firestore reads/writes
- CDN

---

## 4) Subscription packaging (recommended structure)

### Tier: Free (trial)
- **Goal**: prove value, keep costs bounded
- **Includes**
  - 10 stylist messages/day
  - 1 outfit generation/day
  - 0 try-ons/day (or 1/week)
  - Wardrobe items: 10 total
- **Hard caps** prevent runaway Gemini Image calls.

### Tier: Plus
- **Goal**: primary consumer plan
- **Includes**
  - Unlimited stylist chat (soft rate limit)
  - 30 outfit generations/month
  - 10 try-ons/month
  - Wardrobe items: 200
  - Base image generation included (1 refresh/month)

### Tier: Pro
- **Goal**: power users
- **Includes**
  - 120 outfit generations/month
  - 40 try-ons/month
  - Priority queue / faster retries
  - Base image refresh (4/month)
  - Advanced try-on settings (when ready)

### Add-ons (optional)
- Extra try-ons pack (e.g., +20)
- Extra outfit generations pack (e.g., +50)

---

## 5) Prompt to paste into Gemini (to compute real $ and suggest pricing)

Paste the following into Gemini (or any pricing-capable model), then fill the variables from your analytics:

```text
You are a product pricing analyst.

Given the following usage model and unit costs, compute:
1) Monthly cost per active user (average + p90)
2) Break-even subscription prices for gross margin targets: 60%, 75%, 85%
3) Recommended plan tiers (Free/Plus/Pro) with caps that keep p90 cost within budget
4) Suggested feature sets per tier

USAGE (per user per month):
- M = <chat messages>
- O = <outfit generations>
- I = <fraction of outfit generations that call DeepSeek>
- N = <avg images per outfit gen call>
- T = <try-ons>
- W = <wardrobe items added>
- p_new = <fraction new users this month>

UNIT COSTS (current provider pricing):
- C_oa_msg = $<...>
- C_ds = $<...>
- C_gf_mm(N) = $<...> for N images
- C_gf_json = $<...>
- C_gp_id = $<...>
- C_gi_base = $<...>
- C_gi_try = $<...>

FORMULA:
C_user = M*C_oa_msg + O*(I*C_ds + C_gf_mm(N)) + T*C_gi_try + W*C_gf_json + p_new*(C_gp_id + C_gi_base)

Now compute the outputs and present them clearly with assumptions.
```

