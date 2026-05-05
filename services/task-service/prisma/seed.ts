import { PrismaClient, TaskStatus, TaskPriority } from "./generated/index.js";

const prisma = new PrismaClient();

async function main() {
  await prisma.task.deleteMany();

  await prisma.task.createMany({
    data: [
      {
        title: "Finish DevOps project architecture",
        description: "Lock in the Step 1 architecture for TaskTreat.",
        status: TaskStatus.DONE,
        priority: TaskPriority.HIGH,
        completedAt: new Date(),
      },
      {
        title: "Create Terraform modules",
        description: "VPC, RDS, EKS modules for the cluster.",
        status: TaskStatus.DOING,
        priority: TaskPriority.HIGH,
      },
      {
        title: "Set up Grafana OAuth",
        description: "Wire OAuth2 SSO for the observability stack.",
        status: TaskStatus.TODO,
        priority: TaskPriority.MEDIUM,
      },
      {
        title: "Write presentation script",
        description: "Talking points for the live demo.",
        status: TaskStatus.BACKLOG,
        priority: TaskPriority.LOW,
      },
      {
        title: "Test chaos scenario",
        description: "Kill a pod mid-demo and watch it recover.",
        status: TaskStatus.TODO,
        priority: TaskPriority.MEDIUM,
      },
    ],
  });

  const count = await prisma.task.count();
  console.log(`task-service seed complete: ${count} tasks inserted.`);
}

main()
  .catch((err) => {
    console.error(err);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
