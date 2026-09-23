'use client';

import React from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Sparkles, ArrowRight, X } from 'lucide-react';

interface SoftGateModalProps {
    isOpen: boolean;
    onSignIn: () => void;
    onSignInLater: () => void;
}

export function SoftGateModal({ isOpen, onSignIn, onSignInLater }: SoftGateModalProps) {
    if (!isOpen) return null;

    return (
        <AnimatePresence>
            <div className="fixed inset-0 z-[105] flex items-center justify-center p-4">
                {/* Backdrop */}
                <motion.div
                    initial={{ opacity: 0 }}
                    animate={{ opacity: 1 }}
                    exit={{ opacity: 0 }}
                    transition={{ duration: 0.2 }}
                    className="fixed inset-0 bg-black/40 backdrop-blur-sm"
                    onClick={onSignInLater}
                />

                {/* Soft Gate Modal Card */}
                <motion.div
                    initial={{ opacity: 0, scale: 0.94, y: 12 }}
                    animate={{ opacity: 1, scale: 1, y: 0 }}
                    exit={{ opacity: 0, scale: 0.94, y: 12 }}
                    transition={{ type: 'spring', damping: 25, stiffness: 320 }}
                    className="relative w-full max-w-md bg-[#FBFBF9] border border-[#E5E4DF] rounded-3xl shadow-[0_20px_60px_rgba(0,0,0,0.18)] p-7 sm:p-8 overflow-hidden z-10 font-sans text-center"
                    onClick={(e) => e.stopPropagation()}
                >
                    {/* Close button (Dismisses as 'Sign in later') */}
                    <button
                        type="button"
                        onClick={onSignInLater}
                        className="absolute top-5 right-5 p-1.5 rounded-full text-[#111]/40 hover:text-[#111] hover:bg-[#ECEAE4] transition-all cursor-pointer"
                        title="Close and continue as guest"
                    >
                        <X className="w-4 h-4" />
                    </button>

                    {/* Badge Icon */}
                    <div className="w-12 h-12 rounded-2xl bg-[#00C8FF]/10 border border-[#00C8FF]/20 flex items-center justify-center mx-auto mb-4 text-[#00C8FF]">
                        <Sparkles className="w-6 h-6" />
                    </div>

                    <h2 className="text-[20px] font-bold tracking-tight text-[#111] mb-2">
                        Enjoying Zero AI?
                    </h2>

                    <p className="text-xs sm:text-[13px] text-[#111]/70 leading-relaxed mb-6">
                        You've asked 5 questions! Sign in to sync your conversations across devices, access full model features, and save your chat history.
                    </p>

                    {/* Action Buttons */}
                    <div className="flex flex-col gap-2.5">
                        <button
                            type="button"
                            onClick={onSignIn}
                            className="w-full flex items-center justify-center gap-2 h-11 rounded-xl bg-[#111111] text-white font-semibold text-[13.5px] hover:bg-[#222] shadow-sm transition-all cursor-pointer"
                        >
                            <span>Sign in / Create Account</span>
                            <ArrowRight className="w-4 h-4" />
                        </button>

                        <button
                            type="button"
                            onClick={onSignInLater}
                            className="w-full flex items-center justify-center h-10 rounded-xl bg-transparent text-[#111]/60 hover:text-[#111] hover:bg-[#ECEAE4] font-medium text-xs transition-all cursor-pointer"
                        >
                            Sign in later (Continue chatting)
                        </button>
                    </div>
                </motion.div>
            </div>
        </AnimatePresence>
    );
}
