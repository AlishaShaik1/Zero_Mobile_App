import React from 'react';

// Brand Logos for Benchmark visualizer

export function ZeroMascotLogo({ className = 'w-4 h-4' }: { className?: string }) {
  return (
    <img
      src="/titan-mascot.png"
      alt="Zero Mascot"
      className={`${className} object-contain inline-block shrink-0 select-none`}
      draggable={false}
    />
  );
}

export const TitanLogo = ZeroMascotLogo;

export function OpenAILogo({ className = 'w-3.5 h-3.5' }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="currentColor">
      <path d="M22.2819 9.8211a5.9847 5.9847 0 0 0-.5157-4.9108 6.0462 6.0462 0 0 0-6.5098-2.9A6.0651 6.0651 0 0 0 4.9807 4.1818a5.9847 5.9847 0 0 0-3.9977 2.9 6.0462 6.0462 0 0 0 .7427 7.0966 5.98 5.98 0 0 0 .511 4.9107 6.051 6.051 0 0 0 6.5146 2.9001A5.9847 5.9847 0 0 0 13.2599 24a6.0557 6.0557 0 0 0 5.7718-4.2058 5.9894 5.9894 0 0 0 3.9977-2.9001 6.0557 6.0557 0 0 0-.7475-7.0729zm-9.022 12.6081a4.4755 4.4755 0 0 1-2.8764-1.0408l.1419-.0804 4.7783-2.7582a.7948.7948 0 0 0 .3927-.6813v-6.7369l2.02 1.1683a.071.071 0 0 1 .038.052v5.5826a4.5045 4.5045 0 0 1-4.4945 4.4947zm-9.6607-4.1254a4.4708 4.4708 0 0 1-.5346-3.0137l.142.0852 4.783 2.7582a.7712.7712 0 0 0 .7806 0l5.8428-3.3685v2.3324a.0804.0804 0 0 1-.0332.0615L9.74 19.9502a4.4992 4.4992 0 0 1-6.1408-1.6464zM2.3408 7.8956a4.485 4.485 0 0 1 2.3655-1.9728V11.6a.7664.7664 0 0 0 .3879.6765l5.8144 3.3543-2.0201 1.1683a.0757.0757 0 0 1-.071 0l-4.8303-2.7866A4.504 4.504 0 0 1 2.3408 7.8956zm16.0993 3.8558L12.5973 8.3829l2.02-1.1636a.0757.0757 0 0 1 .071 0l4.8303 2.7913a4.4944 4.4944 0 0 1-.6765 8.1042v-5.6724a.79.79 0 0 0-.402-.6906zm2.0107-3.0231l-.142-.0852-4.7735-2.7818a.7759.7759 0 0 0-.7854 0L8.907 9.2297V6.8974a.0662.0662 0 0 1 .0331-.0615L13.918 3.999a4.4992 4.4992 0 0 1 6.5328 4.7293zM8.7082 12.0028l3.2844-1.897 3.2844 1.897v3.794l-3.2844 1.897-3.2844-1.897z" />
    </svg>
  );
}

export function AnthropicLogo({ className = 'w-3.5 h-3.5' }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="currentColor">
      <path d="M13.827 3.518L7.042 20.482h3.407l1.455-3.877h4.372l1.456 3.877h3.407L14.355 3.518h-.528zm.082 3.655l1.637 4.364h-3.274l1.637-4.364zM2.82 20.482h3.332L10.355 3.518H7.023L2.82 20.482z" />
    </svg>
  );
}

export function GoogleLogo({ className = 'w-3.5 h-3.5' }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 24 24">
      <path fill="#4285F4" d="M23.745 12.27c0-.7-.06-1.4-.19-2.07H12v4.51h6.6c-.29 1.52-1.14 2.82-2.4 3.68v3.05h3.88c2.27-2.09 3.66-5.17 3.66-9.17z"/>
      <path fill="#34A853" d="M12 24c3.24 0 5.95-1.08 7.93-2.91l-3.88-3.05c-1.08.72-2.45 1.16-4.05 1.16-3.12 0-5.77-2.1-6.72-4.93H1.25v3.15C3.26 21.36 7.34 24 12 24z"/>
      <path fill="#FBBC05" d="M5.28 14.27c-.25-.72-.38-1.49-.38-2.27s.13-1.55.38-2.27V6.58H1.25C.45 8.18 0 9.98 0 12s.45 3.82 1.25 5.42l4.03-3.15z"/>
      <path fill="#EA4335" d="M12 4.75c1.77 0 3.35.61 4.6 1.8l3.42-3.42C17.95 1.19 15.24 0 12 0 7.34 0 3.26 2.64 1.25 6.58l4.03 3.15c.95-2.83 3.6-4.98 6.72-4.98z"/>
    </svg>
  );
}

export function SarvamLogo({ className = 'w-3.5 h-3.5' }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="currentColor">
      <circle cx="12" cy="12" r="10" fill="#FF6F00" opacity="0.2" />
      <path d="M12 4L15.5 10.5H8.5L12 4Z" fill="#FF6F00" />
      <path d="M12 20L8.5 13.5H15.5L12 20Z" fill="#FF8F00" />
      <circle cx="12" cy="12" r="2.5" fill="#FFA000" />
    </svg>
  );
}

export function DeepSeekLogo({ className = 'w-3.5 h-3.5' }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none">
      <path d="M4 14C4 8.477 8.477 4 14 4C17.5 4 20.5 6 21.5 9C19 8.5 16 9.5 14.5 11.5C13 13.5 13.5 16 12 18C10.5 20 7 20 4 14Z" fill="#1E88E5" />
      <circle cx="9" cy="10" r="1.5" fill="#FFFFFF" />
    </svg>
  );
}
