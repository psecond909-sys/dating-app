const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

initializeApp({
  projectId: 'dating-app-e29f0',
});

const db = getFirestore();

const profiles = [
  {
    id: 'demo_aisha_01',
    name: 'Aisha',
    age: 24,
    gender: 'Female',
    bio: 'Demo profile • Love coffee, music and weekend trips ☕🎵✈️',
    interests: ['Music', 'Travel', 'Coffee'],
  },
  {
    id: 'demo_priya_02',
    name: 'Priya',
    age: 26,
    gender: 'Female',
    bio: 'Demo profile • Foodie who enjoys movies and exploring new places 🍿❤️',
    interests: ['Movies', 'Food', 'Travel'],
  },
  {
    id: 'demo_ananya_03',
    name: 'Ananya',
    age: 23,
    gender: 'Female',
    bio: 'Demo profile • Books, photography and long walks 📚📷',
    interests: ['Books', 'Photography', 'Walking'],
  },
  {
    id: 'demo_sneha_04',
    name: 'Sneha',
    age: 25,
    gender: 'Female',
    bio: 'Demo profile • Positive vibes, dancing and good conversations 💃😊',
    interests: ['Dance', 'Music', 'Friends'],
  },
  {
    id: 'demo_riya_05',
    name: 'Riya',
    age: 27,
    gender: 'Female',
    bio: 'Demo profile • Fitness, travel and trying new food 🏋️🌍🍕',
    interests: ['Fitness', 'Travel', 'Food'],
  },
  {
    id: 'demo_meera_06',
    name: 'Meera',
    age: 24,
    gender: 'Female',
    bio: 'Demo profile • Art, music and peaceful evenings 🎨🎶',
    interests: ['Art', 'Music', 'Nature'],
  },
  {
    id: 'demo_kavya_07',
    name: 'Kavya',
    age: 26,
    gender: 'Female',
    bio: 'Demo profile • Adventure seeker and movie lover 🎬🏕️',
    interests: ['Movies', 'Adventure', 'Travel'],
  },
  {
    id: 'demo_neha_08',
    name: 'Neha',
    age: 25,
    gender: 'Female',
    bio: 'Demo profile • Always ready for a great conversation 😊',
    interests: ['Music', 'Movies', 'Coffee'],
  },
  {
    id: 'demo_ishita_09',
    name: 'Ishita',
    age: 23,
    gender: 'Female',
    bio: 'Demo profile • Photography, sunsets and travel 📸🌅',
    interests: ['Photography', 'Travel', 'Nature'],
  },
  {
    id: 'demo_pooja_10',
    name: 'Pooja',
    age: 28,
    gender: 'Female',
    bio: 'Demo profile • Cooking, movies and family time ❤️',
    interests: ['Cooking', 'Movies', 'Food'],
  },

  {
    id: 'demo_arjun_11',
    name: 'Arjun',
    age: 26,
    gender: 'Male',
    bio: 'Demo profile • Cricket, travel and good food 🏏✈️',
    interests: ['Cricket', 'Travel', 'Food'],
  },
  {
    id: 'demo_rohan_12',
    name: 'Rohan',
    age: 27,
    gender: 'Male',
    bio: 'Demo profile • Music, gym and weekend adventures 🎵💪',
    interests: ['Music', 'Fitness', 'Travel'],
  },
  {
    id: 'demo_rahul_13',
    name: 'Rahul',
    age: 25,
    gender: 'Male',
    bio: 'Demo profile • Movies, coffee and interesting conversations ☕🎬',
    interests: ['Movies', 'Coffee', 'Music'],
  },
  {
    id: 'demo_aditya_14',
    name: 'Aditya',
    age: 24,
    gender: 'Male',
    bio: 'Demo profile • Photography and exploring new cities 📷🌆',
    interests: ['Photography', 'Travel', 'Art'],
  },
  {
    id: 'demo_vikram_15',
    name: 'Vikram',
    age: 28,
    gender: 'Male',
    bio: 'Demo profile • Fitness, football and outdoor activities ⚽🏃',
    interests: ['Football', 'Fitness', 'Sports'],
  },
  {
    id: 'demo_karthik_16',
    name: 'Karthik',
    age: 26,
    gender: 'Male',
    bio: 'Demo profile • Food lover and movie fan 🍕🎬',
    interests: ['Food', 'Movies', 'Travel'],
  },
  {
    id: 'demo_akash_17',
    name: 'Akash',
    age: 25,
    gender: 'Male',
    bio: 'Demo profile • Tech, music and late-night conversations 💻🎵',
    interests: ['Technology', 'Music', 'Movies'],
  },
  {
    id: 'demo_sai_18',
    name: 'Sai',
    age: 27,
    gender: 'Male',
    bio: 'Demo profile • Nature, photography and road trips 🌄📸',
    interests: ['Nature', 'Photography', 'Travel'],
  },
  {
    id: 'demo_rohit_19',
    name: 'Rohit',
    age: 24,
    gender: 'Male',
    bio: 'Demo profile • Cricket, gaming and food 🏏🎮',
    interests: ['Cricket', 'Gaming', 'Food'],
  },
  {
    id: 'demo_varun_20',
    name: 'Varun',
    age: 29,
    gender: 'Male',
    bio: 'Demo profile • Travel, fitness and good conversations 🌍😊',
    interests: ['Travel', 'Fitness', 'Music'],
  },
];

async function main() {
  const batch = db.batch();

  for (const profile of profiles) {
    const ref = db.collection('users').doc(profile.id);

    batch.set(ref, {
      ...profile,
      isDemo: true,
      demoLabel: 'Demo Profile',
      plan: 'free',
      createdAt: FieldValue.serverTimestamp(),
    }, { merge: true });
  }

  await batch.commit();

  console.log(`Added/updated ${profiles.length} demo profiles.`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
