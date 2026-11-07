const notFoundCode = 5;

export function isNotFound(err: unknown): boolean {
  return (err as { code?: unknown } | null)?.code === notFoundCode;
}

// a missing document means the account is being deleted, so the write must not re-create it
export async function updateIfExists(
  ref: FirebaseFirestore.DocumentReference,
  data: FirebaseFirestore.UpdateData<FirebaseFirestore.DocumentData>,
): Promise<boolean> {
  try {
    await ref.update(data);
    return true;
  } catch (err) {
    if (isNotFound(err)) return false;
    throw err;
  }
}
