import { ProductForm } from "@/components/products/ProductForm";
import { db } from '@/lib/db';
import { notFound } from "next/navigation";
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Edit Product",
};

interface PageProps {
  params: Promise<{ id: string }>;
}

export default async function EditProductPage({ params }: PageProps) {
  const resolvedParams = await params;
  const id = resolvedParams.id;
  
  
  const { data: product, error } = await db
    .from("products")
    .select("*")
    .eq("id", id)
    .single();

  if (error || !product) {
    notFound();
  }

  return <ProductForm initialData={product} />;
}
