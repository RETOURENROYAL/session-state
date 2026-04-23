/**
 * R³ VIB.E — CopilotKit Provider + Chat UI
 *
 * Wrap your React app root with this component.
 *
 * Install:
 *   npm install @copilotkit/react-core @copilotkit/react-ui
 *
 * Usage (src/App.tsx or src/index.tsx):
 *   import { R3CopilotProvider } from './components/R3CopilotProvider';
 *   export default function App() {
 *     return <R3CopilotProvider><YourApp /></R3CopilotProvider>;
 *   }
 */

import React from "react";
import { CopilotKit } from "@copilotkit/react-core";
import { CopilotPopup } from "@copilotkit/react-ui";
import "@copilotkit/react-ui/styles.css";

interface Props {
  children: React.ReactNode;
  /** CopilotKit runtime URL — defaults to ChatLegs :8420 */
  runtimeUrl?: string;
}

export function R3CopilotProvider({
  children,
  runtimeUrl = "http://localhost:8420/copilotkit",
}: Props) {
  return (
    <CopilotKit runtimeUrl={runtimeUrl}>
      {children}
      <CopilotPopup
        labels={{
          title: "R³ VIB.E Agent",
          placeholder: "Frag den R³ Agenten … (r3/fast, r3/reasoning, r3/code)",
          initial: "Hallo! Ich habe Zugriff auf alle R³ Tools und Modelle.",
        }}
      />
    </CopilotKit>
  );
}
