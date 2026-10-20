import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';
import { db } from '../shared/admin';
import { requireAppCheck } from '../shared/app_check';

export const sendNudge = functions.https.onCall(async (data, context) => {
  requireAppCheck(context, 'sendNudge');
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated.');
  }

  const groupId = typeof data?.groupId === 'string' ? data.groupId : '';
  const targetUserId = typeof data?.targetUserId === 'string' ? data.targetUserId : '';
  const senderId = context.auth.uid;

  if (!groupId || !targetUserId) {
    throw new functions.https.HttpsError('invalid-argument', 'groupId and targetUserId are required.');
  }
  if (targetUserId === senderId) {
    throw new functions.https.HttpsError('failed-precondition', 'You cannot nudge yourself.');
  }

  const groupRef = db.collection('groups').doc(groupId);
  const [groupSnap, senderMembershipSnap, targetMembershipSnap, targetProfileSnap, senderProfileSnap, targetTokensSnap] = await Promise.all([
    groupRef.get(),
    groupRef.collection('members').doc(senderId).get(),
    groupRef.collection('members').doc(targetUserId).get(),
    db.collection('users').doc(targetUserId).get(),
    db.collection('users').doc(senderId).get(),
    db.collection('users').doc(targetUserId).collection('fcmTokens').get(),
  ]);

  if (!groupSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'Group not found.');
  }
  if (!senderMembershipSnap.exists || !targetMembershipSnap.exists) {
    throw new functions.https.HttpsError('permission-denied', 'Both users must be members of this group.');
  }
  if (!targetProfileSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'Target profile not found.');
  }

  const targetData = targetProfileSnap.data() || {};
  const senderData = senderProfileSnap.data() || {};

  const allowsNudges = targetData.allowNudges !== false;
  if (!allowsNudges) {
    throw new functions.https.HttpsError('failed-precondition', 'This member has disabled nudges.');
  }

  const tokens = targetTokensSnap.docs
    .map((doc) => (doc.data().token as string | undefined) ?? doc.id)
    .filter((token): token is string => typeof token === 'string' && token.trim().length > 0);
  if (tokens.length == 0) {
    throw new functions.https.HttpsError('failed-precondition', 'This member cannot receive nudges right now.');
  }

  const senderName =
    (senderData.profileName as string | undefined)?.trim() ||
    (senderData.displayName as string | undefined)?.trim() ||
    'Someone';

  // Determine target user's preferred language. Support 'ru', 'en', 'kk' (Kazakh).
  const rawLang = ((targetData.language as string | undefined) ||
    (targetData.locale as string | undefined) ||
    (targetData.languageCode as string | undefined) ||
    'en').toLowerCase();
  const lang = rawLang.startsWith('ru') ? 'ru' : (rawLang.startsWith('kk') || rawLang.startsWith('kz') || rawLang.startsWith('kaz') ? 'kk' : 'en');

  // Phrase templates with a <username> placeholder. Localized variants for en/ru/kk.
  const phrases: Record<string, string[]> = {
    en: [
      '<username> nudged you — time to study 💡',
      '<username> thinks it’s study time 👀',
      '<username> sent a nudge — let’s start',
      'Hey, <username> is studying right now 💪',
      "<username> says: a little focus won’t hurt 🙂",
      'Study call from <username> 📚',
      '<username> nudged you — join the grind',
      'Time to focus! <username> is waiting',
      '<username> believes in your study streak 🔥',
      'Quick nudge from <username> - let’s go',
      "<username> says it’s a good moment to study",
      "You’ve got a study ping from <username>",
      '<username> just gave you a focus nudge',
      'Time to lock in - <username> is on it',
      '<username> is studying, join in!',
      'A small nudge from <username> to get started',
      "<username> thinks now’s a good time 📖",
      'Study alert from <username> - let’s do this',
      '<username> invited you to study together',
      "Let’s go - <username> just nudged you",
      "<username> says: don’t miss today’s progress",
      "<username> thinks now is a good moment to learn things",
    ],
    ru: [
      '<username> подтолкнул вас — время учиться 💡',
      '<username> думает, что пора учиться 👀',
      '<username> отправил напоминание — давайте начнём',
      'Привет, <username> сейчас учится 💪',
      '<username> говорит: немного сосредоточенности не повредит 🙂',
      'Зов к учёбе от <username> 📚',
      '<username> подтолкнул вас — присоединяйтесь',
      'Время сосредоточиться! <username> ждёт',
      '<username> верит в вашу серию занятий 🔥',
      'Быстрый nudge от <username> — поехали',
      '<username> говорит, что сейчас хорошее время для учёбы',
      'У вас учебный пинг от <username>',
      '<username> только что дал вам толчок для фокуса',
      'Пора врубиться — <username> уже в деле',
      '<username> учится, присоединяйся!',
      'Небольшое напоминание от <username>, чтобы начать',
      '<username> считает, что сейчас подходящее время 📖',
      'Учебное оповещение от <username> — вперёд',
      '<username> пригласил вас учиться вместе',
      'Вперёд — <username> только что подтолкнул вас',
      '<username> говорит: не упускай прогресс сегодня',
      '<username> считает, что сейчас хорошее время для новых знаний',
    ],
    kk: [
      '<username> сізге серпін берді — оқу уақыты 💡',
      '<username> ойлайды: оқу уақыты келді 👀',
      '<username> нұсқау жіберді — бастайық',
      'Ей, <username> қазір оқып жатыр 💪',
      '<username> айтты: сәл зейін қою зиян келтірмейді 🙂',
      '<username>-тан оқу шақыруы 📚',
      '<username> сізге серпін берді — қосылыңыз',
      'Зейін қой! <username> сізді күтіп тұр',
      '<username> сенің оқу тізбегіңе сенеді 🔥',
      '<username>-тан жедел серпін — бастайық',
      '<username> айтты: бұл оқуға жақсы сәт',
      '<username>-тан оқу хабарламасы сізге келді',
      '<username> сізге фокус толқынын жіберді',
      'Уақыт құлыптау — <username> қазір бастады',
      '<username> оқып жатыр, қосылыңыз!',
      '<username>-тан кішкене серпін — бастау үшін',
      '<username> ойлайды, қазір жақсы уақыт 📖',
      '<username>-тан оқу ескертуі — жасайық',
      '<username> бірге оқу үшін шақырды',
      'Алға — <username> сізге серпін берді',
      '<username> айтты: бүгінгі ілгерілеуді жіберіп алмаңыз',
      '<username> ойлайды: қазір жаңа нәрселер үйренуге жақсы сәт',
    ],
  };

  const list = phrases[lang] || phrases.en;
  const template = list[Math.floor(Math.random() * list.length)];
  const body = template.replace(/<username>/g, senderName);

  const titles: Record<string, string> = {
    en: 'Nudge',
    ru: 'Напоминание',
    kk: 'Ескерту',
  };
  const title = titles[lang] || titles.en;

  try {
    const now = admin.firestore.FieldValue.serverTimestamp();
    
    // 1. Store the nudge persistently
    await db.collection('nudges').add({
      senderId,
      receiverId: targetUserId,
      groupId,
      title,
      body,
      timestamp: now,
      status: 'pending',
    });

    // 2. Attempt FCM Push (Instant Delivery)
    const response = await admin.messaging().sendEachForMulticast({
      tokens,
      notification: {
        title,
        body,
      },
      data: {
        type: 'nudge',
        groupId,
        senderId,
        targetUserId,
      },
    });

    if (response.failureCount > 0) {
      const invalidTokens: string[] = [];
      response.responses.forEach((resp, index) => {
        if (!resp.success) {
          const code = resp.error?.code ?? '';
          if (code === 'messaging/registration-token-not-registered' ||
            code === 'messaging/invalid-registration-token') {
            invalidTokens.push(tokens[index]);
          }
        }
      });

      if (invalidTokens.length > 0) {
        const batch = db.batch();
        for (const token of invalidTokens) {
          batch.delete(
            db.collection('users').doc(targetUserId).collection('fcmTokens').doc(token),
          );
        }
        await batch.commit();
      }
    }

    // Notice we removed the "successCount == 0" throw Error because
    // the nudge is safely stored in Firestore for delivery on app open.
    if (response.successCount === 0) {
      functions.logger.info(`0 devices received push. Nudge is saved in Firestore for ${targetUserId}.`);
    }

    return { success: true };
  } catch (err) {
    functions.logger.error('Failed to process nudge', err);
    if (err instanceof functions.https.HttpsError) {
      throw err;
    }
    throw new functions.https.HttpsError('internal', err instanceof Error ? err.message : 'Failed to send nudge.');
  }
});
