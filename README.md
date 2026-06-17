# SQL Learning Path — MySQL

A structured, hands-on SQL learning repository. Each topic builds on the previous one, with lessons, runnable examples, and practice problems.

## Prerequisites

- MySQL 8.0+ installed
- A database created for practice:
  ```sql
  CREATE DATABASE sql_demo;
  USE sql_demo;
  ```

## How to Use

1. Run `schema/reset.sql` to create all tables with seed data (or run individual schema files in order)
2. Work through lessons in numbered order
3. Each folder contains:
   - **lesson.md** — Read the concepts and examples
   - **lesson.sql** — Run the examples in your MySQL client
   - **practice.md** — Solve problems yourself (hints and solutions included)
   - **practice.sql** — Check your answers

## Topic Map

- [x] 01 — [Views](01-views/lesson.md)
- [x] 02 — [Updatable Views](02-updatable-views/lesson.md)
- [x] 03 — [Stored Procedures](03-stored-procedures/lesson.md)
- [x] 04 — [Triggers](04-triggers/lesson.md)
- [x] 05 — [Indexing](05-indexing/lesson.md)
- [x] 06 — [Transaction Processing](06-transactions/lesson.md)
- [ ] 07 — Concurrency Control

## Schema Overview

Tables are introduced gradually as lessons need them.

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   student    │     │    course     │     │    grade     │
│──────────────│     │──────────────│     │──────────────│
│ student_id   │◄──┐ │ course_id    │◄──┐ │ grade_id     │
│ name         │   │ │ course_code  │   │ │ enrollment_id│──┐
│ email        │   │ │ course_name  │   │ │ letter_grade │  │
│ date_of_birth│   │ │ credits      │   │ │ numeric_grade│  │
│ gender       │   │ │ department   │   │ │ graded_date  │  │
└──────────────┘   │ │ max_enrollment│  │ └──────────────┘  │
                   │ └──────────────┘   │                    │
                   │                     │                    │
                   │ ┌──────────────┐   │                    │
                   │ │  enrollment  │   │                    │
                   │ │──────────────│   │                    │
                   ├─│ student_id   │   │                    │
                   │ │ course_id    │───┘                    │
                   │ │ enrollment_id│◄───────────────────────┘
                   │ │ enrolled_date│
                   │ │ status       │
                   │ └──────────────┘
                   │
                   │ ┌────────────────┐   ┌──────────────┐
                   │ │student_account │   │   payment    │
                   │ │────────────────│   │──────────────│
                   ├─│ student_id     │   │ payment_id   │
                   │ │ balance        │   │ student_id   │──┘
                   │ └────────────────┘   │ amount       │
                   │                       │ payment_date │
                   │                       │ payment_type │
                   └───────────────────────│ description  │
                                           └──────────────┘

  ┌──────────────┐
  │  audit_log   │  (standalone — records changes from triggers)
  │──────────────│
  │ log_id       │
  │ table_name   │
  │ action       │
  │ record_id    │
  │ old_value    │
  │ new_value    │
  │ changed_by   │
  │ changed_at   │
  └──────────────┘
```

| Table | Introduced In | Purpose |
|-------|--------------|---------|
| `student` | 01 Views | Core entity — all lessons use this |
| `course` | 03 Stored Procedures | Course catalog for enrollment demos |
| `enrollment` | 03 Stored Procedures | Links students to courses |
| `grade` | 04 Triggers | Stores grades, triggers fire on changes |
| `audit_log` | 04 Triggers | Logs all data changes from triggers |
| `student_account` | 06 Transactions | Account balances for transaction demos |
| `payment` | 06 Transactions | Payment records for transaction demos |

## Challenges

Cross-topic challenges that tie multiple concepts together:

| Challenge | Attempt After | Description |
|-----------|--------------|-------------|
| [Student Audit Trail](challenges/challenge-01-student-audit.md) | Triggers | Views + procedures + triggers working together |
| [Enrollment Pipeline](challenges/challenge-02-enrollment-pipeline.md) | Transactions | Capacity checks + payment + rollback in one transaction |
| [University Admin Dashboard](challenges/challenge-03-university-admin.md) | All lessons | Capstone project tying all 7 topics together |
