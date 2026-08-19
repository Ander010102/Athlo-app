const { onCall } = require("firebase-functions/v2/https");
const { getFirestore } = require("firebase-admin/firestore");
const admin = require("firebase-admin");
admin.initializeApp();

exports.deleteCommunity = onCall(async (request) => {
  const communityId = request.data.communityId;
  const db = getFirestore();

  // segurança: só o dono pode apagar
  const communityRef = db.collection("communities").doc(communityId);
  const communitySnap = await communityRef.get();
  if (!communitySnap.exists) throw new Error("Comunidade não encontrada");

  const ownerId = communitySnap.data().ownerId;
  if (request.auth?.uid !== ownerId) throw new Error("Permissão negada");

  // Apaga subcoleções (messages, members etc)
  const subCollections = ["messages", "members"];
  for (const sub of subCollections) {
    const subSnap = await communityRef.collection(sub).get();
    const batch = db.batch();
    subSnap.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
  }

  // Por fim, apaga o documento principal
  await communityRef.delete();
  return { success: true };
});
