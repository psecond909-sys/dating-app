const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

const db = getFirestore();

exports.sendNewMessageNotification = onDocumentCreated(
  "chats/{chatId}/messages/{messageId}",
  async (event) => {
    const message = event.data?.data();

    if (!message) {
      return;
    }

    const receiverId = message.receiverId;
    const senderId = message.senderId;

    if (!receiverId || !senderId) {
      return;
    }

    const receiverDoc = await db
      .collection("users")
      .doc(receiverId)
      .get();

    const receiver = receiverDoc.data();

    if (!receiver) {
      return;
    }

    const token = receiver.fcmToken;

    if (!token) {
      console.log("No FCM token for receiver:", receiverId);
      return;
    }

    const senderDoc = await db
      .collection("users")
      .doc(senderId)
      .get();

    const sender = senderDoc.data();

    const senderName = sender?.name || "Someone";

    const messageText = message.type === "image"
      ? "📷 Sent you a photo"
      : (message.text || "Sent you a message");

    try {
      await getMessaging().send({
        token: token,
        notification: {
          title: senderName,
          body: messageText,
        },
        data: {
          chatId: event.params.chatId,
          senderId: senderId,
          type: message.type || "text",
        },
      });

      console.log("Notification sent to:", receiverId);
    } catch (error) {
      console.error("Notification failed:", error);
    }
  }
);
