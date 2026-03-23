#!/usr/bin/env node
/**
 * Style Agent Sidecar
 *
 * Receives a style prompt + current style JSON from the Tauri backend,
 * sends it to Claude via the Claude Code Agent SDK,
 * and returns a JSON diff of style changes.
 *
 * Uses the user's existing Claude Code authentication (Max account).
 * No API key needed.
 */

import { query } from '@anthropic-ai/claude-code';

const SYSTEM_PROMPT = `You are an aesthetic style designer for audio plugin UIs.
You receive a style system JSON and modify it based on the user's request.

The style system has these sections:
- geometry: cornerRadius, borderWidth, shadowBlur, plus per-widget settings (knob, button, toggle, slider, textInput)
- effects: bloom (enabled, size, intensity), shadows (enabled, blur, offsetX, offsetY, alpha), blur
- gradients: buttonGradient, knobGradient, accentGradient (each has enabled, type, angle, stops)
- typography: headingSize, bodySize, labelSize, smallSize, fontWeight, letterSpacing, lineHeight

When the user describes an aesthetic (e.g., "80s Macintosh", "neon cyberpunk", "warm analog"),
translate that into specific property changes across ALL sections.

IMPORTANT: Return ONLY a JSON object with the changed properties as a diff.
Do NOT return the full style system — only the properties that changed.
The diff should mirror the structure: { "geometry": { "button": { "cornerRadius": 0 } } }

If a component is selected, only change properties relevant to that component type.

Example response for "make it more rounded":
{"geometry":{"global":{"cornerRadius":12},"button":{"cornerRadius":12},"toggle":{"trackRounding":12},"slider":{"trackRounding":6},"textInput":{"cornerRadius":12}}}`;

async function main() {
  // Parse the payload from command line args
  const payloadIdx = process.argv.indexOf('--payload');
  if (payloadIdx === -1 || !process.argv[payloadIdx + 1]) {
    console.error(JSON.stringify({ error: 'No --payload argument provided' }));
    process.exit(1);
  }

  let payload;
  try {
    payload = JSON.parse(process.argv[payloadIdx + 1]);
  } catch (e) {
    console.error(JSON.stringify({ error: 'Invalid JSON payload' }));
    process.exit(1);
  }

  const { prompt, styleJSON, selectedComponent, image } = payload;

  // Build the user message
  let userMessage = prompt;
  if (selectedComponent) {
    userMessage = `[Selected component: ${selectedComponent}]\n${prompt}`;
  }

  // Build content array (text + optional image)
  const content = [{ type: 'text', text: userMessage }];

  // Note: image handling would need to be adapted for Claude Code SDK
  // For now, describe the image in text if provided
  if (image) {
    content.push({ type: 'text', text: '[User attached a reference image]' });
  }

  try {
    let fullResponse = '';

    for await (const message of query({
      prompt: `${SYSTEM_PROMPT}\n\nCurrent style system:\n${styleJSON}\n\nUser request: ${userMessage}\n\nReturn ONLY a JSON diff of changes:`,
      options: {
        maxTurns: 1,
        customSystemPrompt: SYSTEM_PROMPT,
      }
    })) {
      if (message.type === 'assistant' && message.message?.content) {
        for (const block of message.message.content) {
          if (block.type === 'text') {
            fullResponse += block.text;
          }
        }
      }
      if (message.type === 'result') {
        fullResponse = message.result || fullResponse;
      }
    }

    // Try to extract JSON from the response
    const jsonMatch = fullResponse.match(/\{[\s\S]*\}/);
    if (jsonMatch) {
      const diff = JSON.parse(jsonMatch[0]);
      console.log(JSON.stringify({ message: 'Style updated', diff }));
    } else {
      console.log(JSON.stringify({ message: fullResponse, diff: {} }));
    }
  } catch (error) {
    console.log(JSON.stringify({
      message: `Agent error: ${error.message}. Make sure Claude Code is authenticated.`,
      diff: {}
    }));
  }
}

main();
