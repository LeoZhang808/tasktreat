import { PrismaClient } from "./generated/index.js";

const prisma = new PrismaClient();

async function main() {
  await prisma.wishlistItem.deleteMany();

  await prisma.wishlistItem.createMany({
    data: [
      { name: "Coffee drink", price: 6.0, category: "Lifestyle", url: null, isPurchased: false },
      { name: "Book", price: 20.0, category: "Reading", url: "https://example.com/book", isPurchased: false },
      { name: "Mechanical keyboard", price: 55.0, category: "Tech", url: "https://example.com/keyboard", isPurchased: false },
      { name: "Headphones", price: 120.0, category: "Tech", url: null, isPurchased: false },
      { name: "Monitor", price: 250.0, category: "Tech", url: null, isPurchased: false },
    ],
  });

  const count = await prisma.wishlistItem.count();
  console.log(`wishlist-service seed complete: ${count} items inserted.`);
}

main()
  .catch((err) => {
    console.error(err);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
