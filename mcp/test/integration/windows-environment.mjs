// StdioClientTransport adds inherited PATH before merging the supplied env.
// Windows environment names are case-insensitive, while JavaScript object keys
// are not. Passing Path alongside that PATH can silently select the old value.
export function windowsEnvironment(environment) {
  return Object.fromEntries(Object.entries(environment).map(([key, value]) => [key.toUpperCase(), value]));
}
