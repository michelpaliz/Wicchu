# Wicchu moderation actions guide

This guide explains where each moderation and safety action is located in the Wicchu Flutter app.

## Roles and report destinations

| Action | Who can use it | Where it goes |
|---|---|---|
| Report a post or comment | Any signed-in user who can see the content | Community moderation queue |
| Report a regular member profile | Signed-in user who shares a community with that member | Community moderation queue |
| Report a community owner, admin, or moderator profile | Signed-in user who shares that community | Wicchu Safety |
| Report a community | Any signed-in user who can open the community | Wicchu Safety |
| Ban or unban a community member | Community owner or administrator | Applied to that community only |
| Appeal a community ban | The banned member | Wicchu Safety |
| Review platform reports and appeals | Wicchu platform moderator | Wicchu Safety |
| Block another user | Any signed-in user viewing another profile | Immediate personal safety action |

Reporting and blocking are separate. Reporting alerts moderators; blocking immediately hides interaction between the two users.

## Ban a member

1. Open **Account**.
2. Under **Management**, select **Spaces I manage**.
3. Select the community.
4. Open **Members**.
5. Select the member.
6. Select **Ban member**.
7. Complete the ban form:
   - **Reason shown to member** is required. The affected member receives and sees this reason.
   - **Internal moderator note** is optional and is only visible to community and Wicchu moderators.
   - **Ban duration** can be **Permanent**, **1 day**, **7 days**, or **30 days**.
8. Select **Ban member** to confirm.

The member loses access to the community immediately. A temporary ban is restored automatically after its expiration date.

## Transfer ownership of a community or local business

Only the current owner can start a transfer, and the recipient must already be an active administrator.

1. Open **Account** → **Spaces I manage**.
2. Select the community, public profile, or local business.
3. Open **Members** or **Followers**.
4. Select an active administrator.
5. Select **Transfer ownership**.
6. Review the confirmation and select **Send transfer**.
7. The administrator opens **Account** → **Invitations**.
8. They review the ownership invitation and select **Accept** or **Decline**.

After acceptance, the recipient becomes the owner and the previous owner becomes an administrator. The transfer expires after seven days if it is not accepted. Starting a new transfer revokes any older pending ownership transfer for that space.

## Step down as an administrator

1. Open the managed community or business.
2. Select **More options** (`•••`).
3. Select **Step down as administrator**.
4. Confirm **Step down**.

The account becomes a regular member and loses management access. Owners must transfer ownership before they can step down or leave.

## Review the details of an existing ban

1. Open **Account** → **Spaces I manage**.
2. Select the community → **Members**.
3. Change the member filter to **Banned** if necessary.
4. Select the banned member.

The action sheet displays the public reason, private moderator note, and return date when the ban is temporary.

## Unban a member

1. Open **Account** → **Spaces I manage**.
2. Select the community → **Members**.
3. Filter by **Banned**.
4. Select the member.
5. Select **Unban member**.
6. Confirm **Unban**.

The member regains community access and receives a notification.

## Appeal a ban as the affected member

1. Find and open the community from **Explore** or community search.
2. The community header displays **Your community access is restricted**.
3. Review the public ban reason and, for a temporary ban, the access-return date.
4. Select **Request Wicchu Safety review**.
5. Explain why the decision should be reviewed.
6. Select **Submit appeal**.

The appeal goes directly to Wicchu platform moderation. It does not go back to the community administrator who issued the ban.

## Review a ban appeal as a Wicchu platform moderator

The account must have the backend `platformModerator` permission. Regular community administrators cannot see this screen.

1. Open **Account**.
2. Under **Management**, select **Wicchu Safety**.
3. Open the **Pending** tab.
4. Find the card labeled **Ban appeal**.
5. Expand **Evidence snapshot** to review the original ban information.
6. Choose one of these actions:
   - **Restore membership** removes the ban and notifies the member.
   - **Dismiss report** keeps the restriction and notifies the member that the appeal was reviewed.
7. Enter an internal resolution note if needed and confirm.
8. Use the **Resolved** tab to review completed decisions and their audit details.

## Report a community to Wicchu Safety

1. Open the community.
2. Select the **More options** (`•••`) button in the top bar.
3. Select **Report community**. Public profiles use **Report page**.
4. Select the appropriate report category.
5. Enter the reason and submit.

This report appears in **Account** → **Wicchu Safety** → **Pending** for platform moderators.

## Contact Wicchu Safety as an owner or administrator

Owners, administrators, and moderators see **Contact Wicchu Safety** instead of reporting their own community or business.

1. Open the managed community, profile, or local business.
2. Select **More options** (`•••`).
3. Select **Contact Wicchu Safety**.
4. Choose the issue, such as a compromised account, administrator abuse, ownership dispute, impersonation, dangerous activity, content that cannot be removed, or a platform restriction.
5. Explain what happened and select **Send to Wicchu Safety**.

The request appears as a **Safety request** in the platform moderation queue. A Wicchu moderator can resolve or dismiss it and record an internal resolution note.

## Report a post

1. Open the post.
2. Select its **More options** (`•••`) menu.
3. Select **Report post**.
4. Choose a category, enter the reason, and submit.
5. After **Report submitted** appears, select **Hide post** if the reporter does not want to see it again.

The report appears in that community's moderation queue.
Hiding is personal and persistent: the post disappears only for the reporter and remains available to moderators while they review the report.

## Report a comment

1. Open the post comments.
2. Select the **More options** (`•••`) button beside the comment.
3. Select **Report comment**.
4. Choose a category, enter the reason, and submit.

## Report a member profile

1. Open another member's profile.
2. Select the **flag** icon labeled **Report profile** in the top bar.
3. Choose a category, enter the reason, and submit.

Wicchu routes the report according to the reported person's role in the shared community:

- Reports about regular members go to the community moderation queue.
- Reports about community owners, administrators, or moderators go to Wicchu Safety, so the reported administrator cannot handle the complaint against themselves.

## Review community reports

1. Open **Account** → **Spaces I manage**.
2. Select the community.
3. Open **Moderation** under **Security**. If reports need attention, the dashboard also shows a **Reports** shortcut.
4. Review the report and its content.
5. Resolve or dismiss it according to the community rules.

Community reports are handled by that community's moderators. Reports about the community itself and ban appeals are handled through Wicchu Safety.

## Block a user

1. Open the other user's profile.
2. Select the **block** icon in the top bar.
3. Review the explanation and select **Block**.

Blocking hides the users' posts, comments, profiles, mentions, and notifications from each other. It does not create a moderation report automatically.

## Suggested reviewer recording

### Community moderation workflow

1. Sign in as a normal member on a physical iPhone.
2. Report a community post.
3. Sign in as the community administrator.
4. Open **Account** → **Spaces I manage** → the community → **Moderation**.
5. Show the report and resolve or dismiss it.
6. Open **Members**, select a test member, and demonstrate the ban form without banning a real user.

### Platform moderation workflow

1. Sign in as the test member and open a community where the account has a test ban.
2. Show the public reason and expiration information.
3. Submit **Request Wicchu Safety review**.
4. Sign in using the preverified platform-moderator account.
5. Open **Account** → **Wicchu Safety** → **Pending**.
6. Open the **Ban appeal**, review its evidence, and choose **Restore membership** or **Dismiss report**.
7. Show the completed action in **Resolved**.

Use dedicated reviewer/test accounts and test content so the recording does not affect real members.
