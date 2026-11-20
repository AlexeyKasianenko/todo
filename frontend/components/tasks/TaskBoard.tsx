"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import Alert from "@mui/material/Alert";
import Snackbar from "@mui/material/Snackbar";
import { ApiError, tasksApi, type Task, type TaskStatus } from "@/lib/api";
import NewTaskForm from "./NewTaskForm";
import TaskFilter, { type Filter } from "./TaskFilter";
import TaskItem from "./TaskItem";
import styles from "./tasks.module.css";

function matchesFilter(task: Task, filter: Filter) {
  if (filter === "all") return true;
  return filter === "done" ? task.status === "done" : task.status !== "done";
}

export default function TaskBoard() {
  const router = useRouter();
  const [tasks, setTasks] = useState<Task[] | null>(null);
  const [filter, setFilter] = useState<Filter>("all");
  const [openId, setOpenId] = useState<number | null>(null);
  const [error, setError] = useState<string | null>(null);

  function showError(e: unknown) {
    if (e instanceof ApiError && e.status === 401) {
      router.replace("/login");
      return;
    }
    setError(e instanceof Error ? e.message : "Something went wrong.");
  }

  useEffect(() => {
    tasksApi
      .list()
      .then(setTasks)
      .catch((e: unknown) => {
        setTasks([]);
        showError(e);
      });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const replaceTask = (updated: Task) =>
    setTasks((prev) => prev?.map((t) => (t.id === updated.id ? updated : t)) ?? prev);

  // Optimistic update with rollback on failure.
  async function updateTask(task: Task, patch: Partial<Pick<Task, "status" | "note">>) {
    replaceTask({ ...task, ...patch });
    try {
      replaceTask(await tasksApi.update(task.id, patch));
    } catch (e) {
      replaceTask(task);
      showError(e);
    }
  }

  async function addTask(title: string) {
    try {
      const task = await tasksApi.create(title);
      setTasks((prev) => [task, ...(prev ?? [])]);
      setOpenId(task.id);
      if (filter === "done") setFilter("all");
      return true;
    } catch (e) {
      showError(e);
      return false;
    }
  }

  async function deleteTask(task: Task) {
    const previous = tasks;
    setTasks((prev) => prev?.filter((t) => t.id !== task.id) ?? prev);
    setOpenId(null);
    try {
      await tasksApi.remove(task.id);
    } catch (e) {
      setTasks(previous);
      showError(e);
    }
  }

  const all = tasks ?? [];
  const doneCount = all.filter((t) => t.status === "done").length;
  const visible = all.filter((t) => matchesFilter(t, filter));

  return (
    <div className={styles.page}>
      <main className={styles.main}>
        <header className={styles.header}>
          <div className={styles.heading}>
            <h1 className={styles.title}>Today</h1>
            <p className={styles.summary}>
              {tasks === null ? "Loading…" : `${doneCount} of ${all.length} done`}
            </p>
          </div>
          <TaskFilter value={filter} onChange={setFilter} />
        </header>

        <NewTaskForm onAdd={addTask} />

        {tasks !== null && (
          <>
            <ul className={styles.list}>
              {visible.map((task) => (
                <TaskItem
                  key={task.id}
                  task={task}
                  open={openId === task.id}
                  onToggleDone={() =>
                    updateTask(task, {
                      status: (task.status === "done" ? "pending" : "done") as TaskStatus,
                    })
                  }
                  onToggleOpen={() => setOpenId(openId === task.id ? null : task.id)}
                  onSaveNote={(note) => updateTask(task, { note })}
                  onDelete={() => deleteTask(task)}
                />
              ))}
            </ul>

            {visible.length === 0 && (
              <p className={styles.empty}>
                {filter === "done" ? "Nothing completed yet." : "All clear. Add a task above."}
              </p>
            )}
          </>
        )}
      </main>

      <Snackbar
        open={error !== null}
        autoHideDuration={5000}
        onClose={() => setError(null)}
        anchorOrigin={{ vertical: "bottom", horizontal: "center" }}
      >
        <Alert severity="error" variant="filled" onClose={() => setError(null)}>
          {error}
        </Alert>
      </Snackbar>
    </div>
  );
}
